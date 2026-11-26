// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'models.dart';

const String kUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

const Map<String, String> kBrowserHeaders = {
  'User-Agent': kUserAgent,
  'Referer': 'https://www.bilibili.com/',
  'Accept': 'application/json, text/plain, */*',
};

const List<int> _mixinKeyEncTab = [
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, //
  27, 43, 5, 49, 33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, //
  37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4, //
  22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52, //
];

String _md5Hex(String input) => md5.convert(utf8.encode(input)).toString();

String _encode(String value) => Uri.encodeComponent(value);

/// 接口的计数字段有时是 num、有时是字符串，还可能是 bool（如 card.following）。
int? _intOrNull(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// B站客户端：搜索、取播放地址、WBI 签名
class BiliClient {
  BiliClient() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        headers: kBrowserHeaders,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
  }

  late final Dio _dio;

  /// 登录态 Cookie（SESSDATA 等），未登录为空
  String loginCookie = '';

  /// 写接口（上报进度）需要的 csrf，来自 bili_jct
  String get csrfToken {
    for (final part in loginCookie.split(';')) {
      final item = part.trim();
      if (item.startsWith('bili_jct=')) {
        return item.substring('bili_jct='.length);
      }
    }
    return '';
  }

  /// 访客指纹（buvid3/buvid4），降低 412 概率
  String visitorCookie = '';

  String? _imgKey;
  String? _subKey;
  DateTime? _keysAt;

  Map<String, String> get headers {
    final cookieParts = <String>[
      if (loginCookie.isNotEmpty) loginCookie,
      if (visitorCookie.isNotEmpty) visitorCookie,
    ];
    return {
      ...kBrowserHeaders,
      if (cookieParts.isNotEmpty) 'Cookie': cookieParts.join('; '),
    };
  }

  /// 播放器（mpv）需要的请求头：B站流有防盗链，必须带 Referer
  /// 查询流大小（HEAD），下载进度加权用。失败返回 0。
  Future<int> headBytes(String url) async {
    final res = await _dio.head<int>(
      url,
      options: Options(
        headers: streamHeaders,
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
    final len = res.headers.value('content-length');
    return int.tryParse(len ?? '') ?? 0;
  }

  Map<String, String> get streamHeaders => {
    'User-Agent': kUserAgent,
    'Referer': 'https://www.bilibili.com/',
    if (loginCookie.isNotEmpty) 'Cookie': loginCookie,
  };

  // ---------------- WBI ----------------

  String _extractKey(String url) {
    final name = url.split('/').last;
    final key = name.replaceAll(RegExp(r'\.[^.]*$'), '');
    if (!RegExp(r'^[A-Za-z0-9]{32}$').hasMatch(key)) {
      throw Exception('WBI key 格式异常');
    }
    return key;
  }

  Future<void> _refreshKeys() async {
    final res = await _dio.get(
      'https://api.bilibili.com/x/web-interface/nav',
      options: Options(headers: headers),
    );
    final data = res.data['data'];
    final wbi = data?['wbi_img'];
    final imgUrl = wbi?['img_url'] as String?;
    final subUrl = wbi?['sub_url'] as String?;
    if (imgUrl == null || subUrl == null) {
      throw Exception('无法获取 WBI 密钥');
    }
    _imgKey = _extractKey(imgUrl);
    _subKey = _extractKey(subUrl);
    _keysAt = DateTime.now();
  }

  Future<String> _mixinKey() async {
    final stale =
        _keysAt == null ||
        DateTime.now().difference(_keysAt!) > const Duration(hours: 6);
    if (_imgKey == null || _subKey == null || stale) {
      await _refreshKeys();
    }
    final raw = '$_imgKey$_subKey';
    final buffer = StringBuffer();
    for (final index in _mixinKeyEncTab) {
      if (index < raw.length) buffer.write(raw[index]);
    }
    return buffer.toString().substring(0, 32);
  }

  /// 返回已签名的参数（含 w_rid / wts）
  Future<Map<String, String>> signWbi(Map<String, Object> params) async {
    final mixin = await _mixinKey();
    final cleaned = <String, String>{};
    params.forEach((key, value) {
      cleaned[key] = value.toString().replaceAll(RegExp(r"[!'()*]"), '');
    });
    cleaned['wts'] = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

    final keys = cleaned.keys.toList()..sort();
    final query = keys
        .map((k) => '${_encode(k)}=${_encode(cleaned[k]!)}')
        .join('&');
    cleaned['w_rid'] = _md5Hex(query + mixin);
    return cleaned;
  }

  String _queryString(Map<String, String> params) => params.entries
      .map((e) => '${_encode(e.key)}=${_encode(e.value)}')
      .join('&');

  // ---------------- 访客身份 ----------------

  Future<void> initVisitor() async {
    try {
      final res = await _dio.get(
        'https://api.bilibili.com/x/frontend/finger/spi',
        options: Options(headers: kBrowserHeaders),
      );
      final data = res.data['data'];
      final b3 = data?['b_3'] as String?;
      final b4 = data?['b_4'] as String?;
      final parts = <String>[
        if (b3 != null) 'buvid3=$b3',
        if (b4 != null) 'buvid4=$b4',
      ];
      visitorCookie = parts.join('; ');
    } catch (_) {
      // 访客指纹拿不到也能继续
    }
  }

  // ---------------- 搜索 ----------------

  /// 搜索视频。
  ///
  /// 支持 B站官网的筛选参数：
  /// - [order] 排序：totalrank 综合 / click 最多播放 / pubdate 最新 / dm 最多弹幕 / stow 最多收藏
  /// - [duration] 时长：0 不限 / 1 ≤1分钟 / 2 1-4分钟 / 3 4-10分钟 / 4 ＞10分钟
  /// - [tids] 分区 id（0 表示不限）
  Future<List<VideoItem>> search(
    String keyword, {
    int page = 1,
    String order = 'totalrank',
    int duration = 0,
    int tids = 0,
  }) async {
    try {
      final signed = await signWbi({
        'search_type': 'video',
        'keyword': keyword,
        'page': page,
        'order': order,
        'duration': duration,
        if (tids > 0) 'tids': tids,
      });
      final url =
          'https://api.bilibili.com/x/web-interface/wbi/search/type?${_queryString(signed)}';
      final res = await _dio.get(url, options: Options(headers: headers));
      if (res.data['code'] == 0) {
        final result = res.data['data']?['result'];
        if (result is List) {
          return result
              .whereType<Map>()
              .map((item) => _parseItem(item.cast<String, dynamic>()))
              .whereType<VideoItem>()
              .toList();
        }
      }
    } catch (_) {
      // 落到下面的降级接口
    }
    return _searchFallback(keyword);
  }

  Future<List<VideoItem>> _searchFallback(String keyword) async {
    try {
      final res = await _dio.get(
        'https://api.bilibili.com/x/web-interface/search/all/v2',
        queryParameters: {'keyword': keyword},
        options: Options(headers: headers),
      );
      final groups = res.data['data']?['result'];
      if (groups is List) {
        for (final group in groups.whereType<Map>()) {
          if (group['result_type'] == 'video' && group['data'] is List) {
            return (group['data'] as List)
                .whereType<Map>()
                .map((item) => _parseItem(item.cast<String, dynamic>()))
                .whereType<VideoItem>()
                .toList();
          }
        }
      }
    } catch (_) {
      // 搜索失败返回空列表，由 UI 提示
    }
    return const [];
  }

  VideoItem? _parseItem(Map<String, dynamic> raw) {
    final bvid = raw['bvid'] as String?;
    if (bvid == null || bvid.isEmpty) return null;
    return VideoItem(
      bvid: bvid,
      title: _cleanText(raw['title'] as String? ?? ''),
      author: raw['author'] as String? ?? '未知UP主',
      cover: _fixPic(raw['pic'] as String? ?? ''),
      play: (raw['play'] as num?)?.toInt() ?? 0,
      durationSeconds: _parseDuration(raw['duration'] as String?),
      pubdate: (raw['pubdate'] as num?)?.toInt() ?? 0,
      mid: (raw['mid'] as num?)?.toInt() ?? 0,
      face: _fixPic(raw['face'] as String? ?? ''),
    );
  }

  String _cleanText(String text) => text
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#39;', "'");

  String _fixPic(String url) => url.startsWith('//')
      ? 'https:$url'
      : url.replaceFirst('http://', 'https://');

  /// 首页推荐流（需 WBI 签名 + buvid3）
  Future<List<VideoItem>> fetchRecommend({int freshIdx = 1}) async {
    try {
      final signed = await signWbi({
        'web_location': 1430650,
        'y_num': 5,
        'fresh_type': 4,
        'feed_version': 'V8',
        'fresh_idx': freshIdx,
        'fresh_idx_1h': freshIdx,
        'brush': 0,
        'homepage_ver': 1,
        'ps': 20,
        'last_y_num': 5,
        'screen': '1920-1080',
        'seo_info': '',
        'section_id': 0,
      });
      final res = await _dio.get(
        'https://api.bilibili.com/x/web-interface/wbi/index/top/feed/rcmd?${_queryString(signed)}',
        options: Options(headers: headers),
      );
      final items = res.data['data']?['item'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .where((raw) => raw['goto'] == 'av')
          .map(_parseFeedItem)
          .whereType<VideoItem>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// 普通分区：优先排行榜，拿不到再退回最新投稿
  Future<List<VideoItem>> fetchCategory(int rid, {int page = 1}) async {
    // 第 1 页优先用排行榜（精选）；后续页用带 rid 的推荐流分页。
    if (page == 1) {
      try {
        final res = await _dio.get(
          'https://api.bilibili.com/x/web-interface/ranking/v2',
          queryParameters: {'rid': rid, 'type': 'all'},
          options: Options(headers: headers),
        );
        final list = res.data['data']?['list'];
        if (res.data['code'] == 0 && list is List && list.isNotEmpty) {
          return list
              .whereType<Map>()
              .map(_parseFeedItem)
              .whereType<VideoItem>()
              .toList();
        }
      } catch (_) {
        // 走下面的兜底
      }
    }
    // newlist 接口的 pn 参数已被 B站忽略（所有页返回相同内容），
    // 靠它翻页会拿到重复数据、去重后列表不再增长而卡住。
    // 改用推荐流接口：带 rid 时按分区筛选，fresh_idx 控制翻页。
    final items = await fetchRegionFeed(rid, freshIdx: page);
    if (items.isNotEmpty) return items;
    // 兜底：最新投稿（只有第 1 页内容，但至少能显示）
    try {
      final res = await _dio.get(
        'https://api.bilibili.com/x/web-interface/newlist',
        queryParameters: {'rid': rid, 'pn': page, 'ps': 30},
        options: Options(headers: headers),
      );
      final archives = res.data['data']?['archives'];
      if (archives is List) {
        return archives
            .whereType<Map>()
            .map(_parseFeedItem)
            .whereType<VideoItem>()
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  /// 分区推荐流：带 rid 时 B站按分区筛选，fresh_idx 递增实现翻页。
  /// 必须携带 buvid3/buvid4，否则 rid 参数会被忽略、返回全站推荐。
  Future<List<VideoItem>> fetchRegionFeed(int rid, {int freshIdx = 1}) async {
    try {
      final signed = await signWbi({
        'web_location': 3331387,
        'y_num': 3,
        'fresh_type': 4,
        'feed_version': 'V8',
        'fresh_idx': freshIdx,
        'fresh_idx_1h': freshIdx,
        'brush': 0,
        'homepage_ver': 1,
        'ps': 30,
        'last_y_num': 3,
        'screen': '1920-1080',
        'seo_info': '',
        'rid': rid,
        'column': 4,
        'device': 'pc',
        'network': 'wifi',
        'platform': 'pc',
        'mobi_app': 'pc',
      });
      final res = await _dio.get(
        'https://api.bilibili.com/x/web-interface/wbi/index/top/feed/rcmd?${_queryString(signed)}',
        options: Options(headers: headers),
      );
      final items = res.data['data']?['item'];
      if (items is! List) return const [];
      return items
          .whereType<Map>()
          .where((raw) => raw['goto'] == 'av')
          .map(_parseFeedItem)
          .whereType<VideoItem>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// 版权分区（番剧 1 / 国创 4 / 综艺 7）的季列表
  Future<List<VideoItem>> fetchBangumiFeed(
    int seasonType, {
    int page = 1,
  }) async {
    try {
      final res = await _dio.get(
        'https://api.bilibili.com/pgc/season/index/result',
        queryParameters: {
          'season_type': seasonType,
          'order': 3,
          'pagesize': 30,
          'page': page,
          'type': 1,
        },
        options: Options(headers: headers),
      );
      final list = res.data['data']?['list'];
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map(
            (raw) => VideoItem(
              bvid: '',
              title: _cleanText(raw['title'] as String? ?? ''),
              author: '',
              cover: _fixPic(raw['cover'] as String? ?? ''),
              play: 0,
              durationSeconds: 0,
              pubdate: 0,
              seasonId: (raw['season_id'] as num?)?.toInt(),
              subtitle: raw['index_show'] as String? ?? '',
            ),
          )
          .where((item) => item.seasonId != null)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  VideoItem? _parseFeedItem(Map raw) {
    final bvid = raw['bvid'] as String?;
    if (bvid == null || bvid.isEmpty) return null;
    final owner = raw['owner'];
    final stat = raw['stat'];
    return VideoItem(
      bvid: bvid,
      title: _cleanText(raw['title'] as String? ?? ''),
      author: (owner is Map ? owner['name'] as String? : null) ?? '未知UP主',
      cover: _fixPic(raw['pic'] as String? ?? ''),
      play: (stat is Map ? (stat['view'] as num?)?.toInt() : null) ?? 0,
      durationSeconds: (raw['duration'] as num?)?.toInt() ?? 0,
      pubdate: (raw['pubdate'] as num?)?.toInt() ?? 0,
    );
  }

  int _parseDuration(String? text) {
    if (text == null || text.isEmpty) return 0;
    final parts = text.split(':').map((p) => int.tryParse(p) ?? 0).toList();
    if (parts.isEmpty) return 0;
    return parts.fold<int>(0, (total, part) => total * 60 + part);
  }

  // ---------------- 手工输入网址 ----------------

  /// 把 b23.tv 短链展开成最终地址；非短链原样返回。
  ///
  /// 短链可能靠 302 跳转，也可能在 HTML 里放 BV 号，两种情况都兼容。
  Future<String> expandShortUrl(String url) async {
    if (!RegExp(r'b23\.tv', caseSensitive: false).hasMatch(url)) return url;
    try {
      final res = await _dio.get<String>(
        url.startsWith('http') ? url : 'https://$url',
        options: Options(
          headers: headers,
          followRedirects: true,
          maxRedirects: 8,
        ),
      );
      final finalUrl = res.realUri.toString();
      final bv = RegExp(r'BV[0-9A-Za-z]{10}').firstMatch(finalUrl);
      if (bv != null) return finalUrl;
      final inBody = RegExp(r'BV[0-9A-Za-z]{10}').firstMatch(res.data ?? '');
      if (inBody != null) {
        return 'https://www.bilibili.com/video/${inBody.group(0)}';
      }
      return finalUrl;
    } catch (_) {
      return url;
    }
  }

  /// 从网址（或裸 BV/av 号）里提取 BV 号，提取不到返回 null。
  String? parseBvid(String input) {
    final bv = RegExp(r'BV[0-9A-Za-z]{10}').firstMatch(input);
    if (bv != null) return bv.group(0);
    return null;
  }

  /// 从 av 号网址提取数字 id，提取不到返回 null。
  int? parseAid(String input) {
    final av = RegExp(
      r'(?:video/)?av(\d+)',
      caseSensitive: false,
    ).firstMatch(input);
    if (av == null) return null;
    return int.tryParse(av.group(1) ?? '');
  }

  /// 按 BV 号或 av 号取一条视频的基本信息，供「输入网址直接播放」构造列表项。
  Future<VideoItem> fetchVideoItem(String id) async {
    final isAid = RegExp(r'^\d+$').hasMatch(id);
    final res = await _dio.get(
      'https://api.bilibili.com/x/web-interface/view',
      queryParameters: isAid ? {'aid': id} : {'bvid': id},
      options: Options(headers: headers),
    );
    final data = res.data['data'];
    if (data == null) {
      throw Exception('视频不存在或已下架 code=${res.data['code']}');
    }
    final owner = (data['owner'] as Map?) ?? const {};
    final stat = (data['stat'] as Map?) ?? const {};
    return VideoItem(
      bvid: (data['bvid'] ?? id).toString(),
      title: (data['title'] ?? id).toString(),
      author: (owner['name'] ?? '').toString(),
      cover: (data['pic'] ?? '').toString(),
      play: (stat['view'] as num?)?.toInt() ?? 0,
      durationSeconds: (data['duration'] as num?)?.toInt() ?? 0,
      pubdate: (data['pubdate'] as num?)?.toInt() ?? 0,
      mid: (owner['mid'] as num?)?.toInt() ?? 0,
      face: (owner['face'] ?? '').toString(),
    );
  }

  // ---------------- 播放地址 ----------------

  /// 视频详情：分P 列表 + 合集正片
  Future<VideoDetail> fetchDetail(String bvid) async {
    final res = await _dio.get(
      'https://api.bilibili.com/x/web-interface/view',
      queryParameters: {'bvid': bvid},
      options: Options(headers: headers),
    );
    final data = res.data['data'];
    if (data == null) {
      throw Exception('获取视频信息失败 code=${res.data['code']}');
    }
    final pages = <VideoPage>[];
    for (final raw in (data['pages'] as List?) ?? const []) {
      final map = raw as Map;
      pages.add(
        VideoPage(
          page: (map['page'] as num?)?.toInt() ?? pages.length + 1,
          title: (map['part'] as String?) ?? '',
          cid: (map['cid'] ?? '').toString(),
          durationSeconds: (map['duration'] as num?)?.toInt() ?? 0,
        ),
      );
    }

    String? seasonTitle;
    final episodes = <SeasonEpisode>[];
    final season = data['ugc_season'];
    if (season is Map) {
      seasonTitle = season['title'] as String?;
      for (final section in (season['sections'] as List?) ?? const []) {
        final sectionMap = section as Map;
        final sectionTitle = sectionMap['title'] as String? ?? '';
        for (final raw in (sectionMap['episodes'] as List?) ?? const []) {
          final map = raw as Map;
          final arc = map['arc'];
          episodes.add(
            SeasonEpisode(
              bvid: map['bvid'] as String? ?? bvid,
              cid: (map['cid'] ?? '').toString(),
              title: (map['title'] as String? ?? '').trim(),
              sectionTitle: sectionTitle,
              durationSeconds:
                  (arc is Map ? (arc['duration'] as num?)?.toInt() : null) ?? 0,
            ),
          );
        }
      }
    }

    final owner = data['owner'];
    return VideoDetail(
      cid: (data['cid'] ?? '').toString(),
      aid: (data['aid'] as num?)?.toInt() ?? 0,
      title: data['title'] as String? ?? '',
      description: data['desc'] as String? ?? '',
      pages: pages,
      seasonTitle: seasonTitle,
      episodes: episodes,
      ownerMid: (owner is Map ? (owner['mid'] as num?)?.toInt() : null) ?? 0,
      ownerFace: _fixPic(owner is Map ? (owner['face'] as String?) ?? '' : ''),
    );
  }

  // ---------------- UP 主空间 ----------------

  /// UP 主资料。实测：`x/space/wbi/acc/info` 必须带 WBI 签名 + 登录 Cookie，
  /// 未登录/无 Cookie 会返回 -352 风控；关注/粉丝数从 card 接口取。
  Future<UpInfo> fetchUpInfo(int mid) async {
    final signed = await signWbi({'mid': mid, 'web_location': 1550101});
    final res = await _dio.get(
      'https://api.bilibili.com/x/space/wbi/acc/info?${_queryString(signed)}',
      options: Options(headers: headers),
    );
    if (res.data['code'] != 0) {
      throw Exception(
        '获取UP主信息失败 code=${res.data['code']} ${res.data['message'] ?? ''}',
      );
    }
    final d = res.data['data'] ?? {};
    final cardRes = await _dio.get(
      'https://api.bilibili.com/x/web-interface/card',
      queryParameters: {'mid': mid},
      options: Options(headers: headers),
    );
    final card = cardRes.data['code'] == 0 ? (cardRes.data['data'] ?? {}) : {};
    final official = d['official'];

    var topPhoto = (d['top_photo_v2'] ?? d['top_photo'] ?? '').toString();
    if (topPhoto.isNotEmpty && !topPhoto.startsWith('http')) {
      topPhoto = 'https://i0.hdslb.com/$topPhoto';
    }
    return UpInfo(
      mid: (d['mid'] as num?)?.toInt() ?? mid,
      name: d['name'] as String? ?? 'UP主',
      face: _fixPic(d['face'] as String? ?? ''),
      sign: d['sign'] as String? ?? '',
      level: (d['level'] as num?)?.toInt() ?? 0,
      officialTitle: official is Map
          ? (official['title'] as String?) ?? ''
          : '',
      topPhoto: _fixPic(topPhoto),
      // card.following 是 bool（表示当前登录者是否关注），不是关注数；
      // 接口没给关注总数时用 -1 表示不可用，UI 会隐藏这一项。
      following:
          _intOrNull(card['following']) ?? _intOrNull(d['following']) ?? -1,
      follower: _intOrNull(card['follower']) ?? _intOrNull(d['follower']) ?? 0,
      likes: _intOrNull(card['likes']) ?? 0,
    );
  }

  /// UP 主投稿视频（wbi/arc/search，实测 pubdate/click 排序生效）。
  Future<({List<VideoItem> items, int count})> fetchUpVideos(
    int mid, {
    int pn = 1,
    int ps = 30,
    String order = 'pubdate',
    String face = '',
  }) async {
    final signed = await signWbi({
      'mid': mid,
      'pn': pn,
      'ps': ps,
      'order': order,
      'web_location': 1550101,
    });
    final res = await _dio.get(
      'https://api.bilibili.com/x/space/wbi/arc/search?${_queryString(signed)}',
      options: Options(headers: headers),
    );
    if (res.data['code'] != 0) {
      throw Exception(
        '获取UP主视频失败 code=${res.data['code']} ${res.data['message'] ?? ''}',
      );
    }
    final data = res.data['data'] ?? {};
    final rawList = (data['list']?['vlist'] as List?) ?? const [];
    final items = rawList
        .whereType<Map>()
        .map((m) {
          final raw = m.cast<String, dynamic>();
          return VideoItem(
            bvid: raw['bvid'] as String? ?? '',
            title: _cleanText(raw['title'] as String? ?? ''),
            author: raw['author'] as String? ?? '',
            cover: _fixPic(raw['pic'] as String? ?? ''),
            play: (raw['play'] as num?)?.toInt() ?? 0,
            durationSeconds: _parseDuration(raw['length'] as String?),
            pubdate: (raw['created'] as num?)?.toInt() ?? 0,
            mid: (raw['mid'] as num?)?.toInt() ?? mid,
            face: _fixPic(raw['face'] as String? ?? face),
          );
        })
        .where((item) => item.bvid.isNotEmpty)
        .toList();
    final count = (data['page']?['count'] as num?)?.toInt() ?? items.length;
    return (items: items, count: count);
  }

  /// UP 主动态。实测接口无需 WBI 签名，但 Referer 必须指向空间页。
  Future<({List<UpDynamic> items, String offset, bool hasMore})>
  fetchUpDynamics(int mid, {String offset = ''}) async {
    final res = await _dio.get(
      'https://api.bilibili.com/x/polymer/web-dynamic/v1/feed/space',
      queryParameters: {
        'host_mid': mid,
        'offset': offset,
        'timezone_offset': -480,
        'features': 'itemOpusStyle',
      },
      options: Options(
        headers: {
          ...headers,
          'Referer': 'https://space.bilibili.com/$mid/dynamic',
        },
      ),
    );
    if (res.data['code'] != 0) {
      throw Exception(
        '获取动态失败 code=${res.data['code']} ${res.data['message'] ?? ''}',
      );
    }
    final data = res.data['data'] ?? {};
    final rawItems = (data['items'] as List?) ?? const [];
    final items = rawItems.whereType<Map>().map((m) {
      final raw = m.cast<String, dynamic>();
      final modules = (raw['modules'] as Map?) ?? {};
      final author = (modules['module_author'] as Map?) ?? {};
      final dynamicBlock = (modules['module_dynamic'] as Map?) ?? {};
      final desc = (dynamicBlock['desc'] as Map?) ?? {};
      var text = (desc['text'] as String?) ?? '';
      var cover = '';
      var title = '';
      var bvid = '';
      var playText = '';
      var durationText = '';

      final major = (dynamicBlock['major'] as Map?) ?? {};
      if (major['type'] == 'MAJOR_TYPE_ARCHIVE') {
        final archive = (major['archive'] as Map?) ?? {};
        cover = _fixPic(archive['cover'] as String? ?? '');
        title = _cleanText(archive['title'] as String? ?? '');
        bvid = archive['bvid'] as String? ?? '';
        final stat = (archive['stat'] as Map?) ?? {};
        playText = (stat['play'] as String?) ?? '';
        durationText = (archive['duration_text'] as String?) ?? '';
        if (text.isEmpty) text = _cleanText(archive['desc'] as String? ?? '');
      } else if (major['type'] == 'MAJOR_TYPE_OPUS') {
        final opus = (major['opus'] as Map?) ?? {};
        final summary = (opus['summary'] as Map?) ?? {};
        if (text.isEmpty) text = (summary['text'] as String?) ?? '';
        final pics = (opus['pics'] as List?) ?? const [];
        if (pics.isNotEmpty && pics.first is Map) {
          cover = _fixPic((pics.first as Map)['url'] as String? ?? '');
        }
      } else {
        final draw = (major['draw'] as Map?) ?? {};
        final pics = (draw['pics'] as List?) ?? const [];
        if (pics.isNotEmpty && pics.first is Map) {
          cover = _fixPic((pics.first as Map)['url'] as String? ?? '');
        }
      }
      return UpDynamic(
        id: raw['id_str'] as String? ?? '',
        timeText: (author['pub_time'] as String?) ?? '',
        text: _cleanText(text),
        cover: cover,
        title: title,
        bvid: bvid,
        playText: playText,
        durationText: durationText,
      );
    }).toList();
    return (
      items: items,
      offset: data['offset']?.toString() ?? '',
      hasMore: data['has_more'] == true && items.isNotEmpty,
    );
  }

  /// UP 主合集/视频列表（含 seasons 和 series）。实测 Referer 需指向空间 lists 页。
  Future<List<UpCollection>> fetchUpCollections(int mid) async {
    final res = await _dio.get(
      'https://api.bilibili.com/x/polymer/web-space/home/seasons_series',
      queryParameters: {
        'mid': mid,
        'page_num': 1,
        'page_size': 20,
        'web_location': 333.999,
      },
      options: Options(
        headers: {
          ...headers,
          'Referer': 'https://space.bilibili.com/$mid/lists',
        },
      ),
    );
    if (res.data['code'] != 0) {
      throw Exception(
        '获取合集失败 code=${res.data['code']} ${res.data['message'] ?? ''}',
      );
    }
    final lists = (res.data['data']?['items_lists'] as Map?) ?? {};
    final groups = <dynamic>[
      ...((lists['seasons_list'] as List?) ?? const []),
      ...((lists['series_list'] as List?) ?? const []),
    ];
    return groups.whereType<Map>().map((g) {
      final meta = (g['meta'] as Map?) ?? {};
      final archives = (g['archives'] as List?) ?? const [];
      final videos = archives
          .whereType<Map>()
          .map((m) {
            final raw = m.cast<String, dynamic>();
            final stat = (raw['stat'] as Map?) ?? {};
            return VideoItem(
              bvid: raw['bvid'] as String? ?? '',
              title: _cleanText(raw['title'] as String? ?? ''),
              author: '',
              cover: _fixPic(raw['pic'] as String? ?? ''),
              play: _intOrNull(stat['view']) ?? 0,
              durationSeconds: _intOrNull(raw['duration']) ?? 0,
              pubdate: _intOrNull(raw['pubdate']) ?? 0,
              mid: mid,
            );
          })
          .where((v) => v.bvid.isNotEmpty)
          .toList();
      final id = meta['season_id'] ?? meta['series_id'] ?? '';
      return UpCollection(
        id: id.toString(),
        name: _cleanText(
          meta['name'] as String? ?? meta['title'] as String? ?? '',
        ),
        cover: _fixPic(meta['cover'] as String? ?? ''),
        description: _cleanText(meta['description'] as String? ?? ''),
        total: _intOrNull(meta['total']) ?? videos.length,
        videos: videos,
      );
    }).toList();
  }

  Future<String> _getCid(String bvid) async {
    final res = await _dio.get(
      'https://api.bilibili.com/x/web-interface/view',
      queryParameters: {'bvid': bvid},
      options: Options(headers: headers),
    );
    final data = res.data['data'];
    final cid = data?['cid'];
    if (cid == null) {
      throw Exception('获取视频信息失败 code=${res.data['code']}');
    }
    return cid.toString();
  }

  /// 取视频的 DASH 音视频流；[cid] 指定分P，不传则取第一个分P
  Future<ResolvedPlay> resolve(String bvid, {String? cid}) async {
    final targetCid = (cid != null && cid.isNotEmpty)
        ? cid
        : await _getCid(bvid);
    final res = await _dio.get(
      'https://api.bilibili.com/x/player/playurl',
      queryParameters: {
        'bvid': bvid,
        'cid': targetCid,
        'qn': 127,
        'fnval': 4048,
        'fnver': 0,
        'fourk': 1,
      },
      options: Options(headers: headers),
    );
    final data = res.data['data'];
    final dash = data?['dash'];
    if (dash == null) {
      throw Exception('获取播放地址失败 code=${res.data['code']}');
    }
    return _parseDash(data, targetCid);
  }

  /// 版权内容（番剧/国创/综艺）的播放地址
  Future<ResolvedPlay> resolvePgc(int epId) async {
    final res = await _dio.get(
      'https://api.bilibili.com/pgc/player/web/playurl',
      queryParameters: {
        'ep_id': epId,
        'qn': 127,
        'fnval': 4048,
        'fnver': 0,
        'fourk': 1,
      },
      options: Options(headers: headers),
    );
    final result = res.data['result'];
    if (result == null || result['dash'] == null) {
      final message = res.data['message'] ?? res.data['code'];
      throw Exception('版权内容不可播放（$message），可能需要大会员或该地区受限');
    }
    return _parseDash(result, 'ep$epId');
  }

  /// 一季的剧集列表；[seasonId] 与 [epId] 二选一（epId 用于从云端历史反查所属季）
  Future<PgcSeason> fetchSeason({int? seasonId, int? epId}) async {
    if (seasonId == null && epId == null) {
      throw Exception('缺少季或集的 id');
    }
    final res = await _dio.get(
      'https://api.bilibili.com/pgc/view/web/season',
      queryParameters: {
        if (seasonId != null) 'season_id': seasonId,
        if (seasonId == null && epId != null) 'ep_id': epId,
      },
      options: Options(headers: headers),
    );
    final result = res.data['result'];
    if (result == null) {
      throw Exception('获取剧集失败 code=${res.data['code']}');
    }
    final episodes = <PgcEpisode>[];
    for (final raw in (result['episodes'] as List?) ?? const []) {
      final map = raw as Map;
      final longTitle = (map['long_title'] as String? ?? '').trim();
      episodes.add(
        PgcEpisode(
          epId: (map['id'] as num?)?.toInt() ?? 0,
          aid: (map['aid'] as num?)?.toInt() ?? 0,
          bvid: map['bvid'] as String? ?? '',
          cid: (map['cid'] ?? '').toString(),
          title: longTitle.isNotEmpty
              ? longTitle
              : (map['title'] as String? ?? ''),
          badge: map['title'] as String? ?? '',
          durationSeconds: ((map['duration'] as num?)?.toInt() ?? 0) ~/ 1000,
        ),
      );
    }
    return PgcSeason(
      seasonId: (result['season_id'] as num?)?.toInt() ?? seasonId ?? 0,
      title: result['title'] as String? ?? '',
      cover: _fixPic(result['cover'] as String? ?? ''),
      subtitle: result['subtitle'] as String? ?? '',
      episodes: episodes,
    );
  }

  /// 把弹幕响应字节解码为 XML 文本。
  ///
  /// B站的 comment.bilibili.com 会以 `Content-Encoding: deflate` 返回
  /// **raw deflate**（无 zlib 头），Dart 的 HttpClient 不会自动解压，
  /// 直接 toString() 会得到乱码，导致解析出 0 条弹幕。这里按魔数探测并
  /// 依次尝试 raw deflate / zlib / gzip / 明文。
  String _decodeDanmakuXml(dynamic data) {
    Uint8List bytes;
    if (data is Uint8List) {
      bytes = data;
    } else if (data is List<int>) {
      bytes = Uint8List.fromList(data);
    } else {
      return data?.toString() ?? '';
    }
    if (bytes.isEmpty) return '';

    // 明文 XML（以 '<' 开头）
    if (bytes.first == 0x3C) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    // raw deflate：B站实际返回，典型头字节 0x78 之前无任何 zlib 头
    try {
      final raw = const ZLibDecoder().decodeBytes(bytes, raw: true);
      if (raw.isNotEmpty && raw.first == 0x3C) {
        return utf8.decode(raw, allowMalformed: true);
      }
    } catch (_) {}
    // zlib deflate（带 2 字节头）
    try {
      final raw = const ZLibDecoder().decodeBytes(bytes);
      if (raw.isNotEmpty && raw.first == 0x3C) {
        return utf8.decode(raw, allowMalformed: true);
      }
    } catch (_) {}
    // gzip
    try {
      final raw = GZipDecoder().decodeBytes(bytes);
      if (raw.isNotEmpty && raw.first == 0x3C) {
        return utf8.decode(raw, allowMalformed: true);
      }
    } catch (_) {}
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// 拉取弹幕（XML，按 cid）
  Future<List<DanmakuItem>> fetchDanmaku(String cid) async {
    final res = await _dio.get(
      'https://comment.bilibili.com/$cid.xml',
      options: Options(headers: headers, responseType: ResponseType.bytes),
    );
    final xml = _decodeDanmakuXml(res.data);
    final items = <DanmakuItem>[];
    final regex = RegExp(r'<d p="([^"]*)"[^>]*>([\s\S]*?)</d>');
    for (final match in regex.allMatches(xml)) {
      final parts = (match.group(1) ?? '').split(',');
      if (parts.length < 4) continue;
      final time = double.tryParse(parts[0]) ?? 0;
      final mode = int.tryParse(parts[1]) ?? 1;
      final fontSize = int.tryParse(parts[2]) ?? 25;
      final color = int.tryParse(parts[3]) ?? 0xFFFFFF;
      final text = _unescapeXml(match.group(2) ?? '').trim();
      if (text.isEmpty) continue;
      items.add(
        DanmakuItem(
          time: time,
          mode: mode,
          fontSize: fontSize,
          color: color,
          text: text,
        ),
      );
    }
    items.sort((a, b) => a.time.compareTo(b.time));
    return items;
  }

  String _unescapeXml(String text) {
    var result = text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&');
    result = result.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (match) => String.fromCharCode(int.tryParse(match.group(1)!) ?? 32),
    );
    return result;
  }

  /// 发送弹幕；成功返回 null，失败返回错误提示
  Future<String?> sendDanmaku({
    required int aid,
    required String cid,
    required String bvid,
    required String text,
    required int progressMs,
  }) async {
    final csrf = csrfToken;
    if (csrf.isEmpty) return '未登录，无法发送弹幕';
    final oid = int.tryParse(cid);
    if (oid == null) return '当前内容暂不支持发送弹幕';
    try {
      final res = await _dio.post(
        'https://api.bilibili.com/x/v2/dm/post',
        data: {
          'type': 1,
          'oid': oid,
          'msg': text,
          'bvid': bvid,
          'progress': progressMs,
          'color': 16777215,
          'fontsize': 25,
          'pool': 0,
          'mode': 1,
          // 带上 rnd 可把发送冷却从 90 秒降到 5 秒
          'rnd': DateTime.now().microsecondsSinceEpoch,
          'csrf': csrf,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {...headers, 'Origin': 'https://www.bilibili.com'},
        ),
      );
      final code = res.data['code'];
      if (code == 0) return null;
      return res.data['message']?.toString() ?? '发送失败（$code）';
    } catch (error) {
      return '发送失败：$error';
    }
  }

  /// 上报播放进度到 B站（手机端/网页端可接着看）
  Future<bool> reportProgress({
    required int aid,
    required int cid,
    required int progressSeconds,
  }) async {
    final csrf = csrfToken;
    if (csrf.isEmpty || aid <= 0 || cid <= 0) return false;
    try {
      final res = await _dio.post(
        'https://api.bilibili.com/x/v2/history/report',
        data: {
          'aid': aid,
          'cid': cid,
          'progress': progressSeconds,
          'csrf': csrf,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {...headers, 'Origin': 'https://www.bilibili.com'},
        ),
      );
      return res.data['code'] == 0;
    } catch (_) {
      return false;
    }
  }

  /// 拉取云端观看记录（分页游标接口），用于跨设备续播
  Future<List<CloudHistoryItem>> fetchCloudHistory({int maxPages = 3}) async {
    final items = <CloudHistoryItem>[];
    var max = 0;
    var viewAt = 0;
    for (var page = 0; page < maxPages; page++) {
      final res = await _dio.get(
        'https://api.bilibili.com/x/web-interface/history/cursor',
        queryParameters: {
          'max': max,
          'view_at': viewAt,
          'business': '',
          'ps': 30,
        },
        options: Options(headers: headers),
      );
      final data = res.data['data'];
      if (data == null) break;
      final list = data['list'];
      if (list is! List || list.isEmpty) break;
      for (final raw in list.whereType<Map>()) {
        final history = raw['history'];
        if (history is! Map) continue;
        final title = _cleanText(raw['title'] as String? ?? '');
        final cover = _fixPic(raw['cover'] as String? ?? '');
        final part = history['part'] as String? ?? '';
        final progress = (raw['progress'] as num?)?.toInt() ?? 0;
        final duration = (raw['duration'] as num?)?.toInt() ?? 0;
        final viewedAt = (raw['view_at'] as num?)?.toInt() ?? 0;
        final business = history['business'] as String? ?? 'archive';
        if (business == 'pgc') {
          final epId = (history['epid'] as num?)?.toInt() ?? 0;
          if (epId <= 0) continue;
          items.add(
            CloudHistoryItem(
              kind: 'pgc',
              bvid: '',
              cid: (history['cid'] ?? '').toString(),
              epId: epId,
              title: title,
              partTitle: part,
              cover: cover,
              progressSeconds: progress > 0 ? progress : 0,
              durationSeconds: duration,
              viewAt: viewedAt,
            ),
          );
        } else {
          final bvid = history['bvid'] as String? ?? '';
          final cid = (history['cid'] ?? '').toString();
          if (bvid.isEmpty || cid.isEmpty) continue;
          items.add(
            CloudHistoryItem(
              kind: 'video',
              bvid: bvid,
              cid: cid,
              title: title,
              partTitle: part,
              cover: cover,
              progressSeconds: progress > 0 ? progress : 0,
              durationSeconds: duration,
              viewAt: viewedAt,
            ),
          );
        }
      }
      final cursor = data['cursor'];
      final nextMax =
          (cursor is Map ? (cursor['max'] as num?)?.toInt() : null) ?? 0;
      final nextView =
          (cursor is Map ? (cursor['view_at'] as num?)?.toInt() : null) ?? 0;
      if (nextMax == max && nextView == viewAt) break;
      max = nextMax;
      viewAt = nextView;
      if (list.length < 30) break;
    }
    return items;
  }

  /// 解析 DASH 音视频流（普通视频与版权内容共用）
  ResolvedPlay _parseDash(Map data, String cid) {
    final dash = data['dash'] as Map;

    // 同一画质可能有多种编码，优先 H.264
    final byId = <int, DashStream>{};
    for (final raw in (dash['video'] as List)) {
      final stream = _parseStream(raw as Map);
      final existing = byId[stream.id];
      if (existing == null ||
          (stream.codecs.startsWith('avc1') &&
              !existing.codecs.startsWith('avc1'))) {
        byId[stream.id] = stream;
      }
    }
    final videos = byId.values.toList()..sort((a, b) => b.id.compareTo(a.id));

    // 音频只留一条：优先 AAC-LC、码率最高
    final audioRaw = (dash['audio'] as List?) ?? const [];
    final audios = audioRaw.map((e) => _parseStream(e as Map)).toList()
      ..sort((a, b) => b.bandwidth.compareTo(a.bandwidth));
    final aac = audios.where((a) => a.codecs.startsWith('mp4a.40.2')).toList();
    final audio = aac.isNotEmpty
        ? aac.first
        : (audios.isNotEmpty ? audios.first : null);

    final duration = (data['timelength'] as num?)?.toInt();
    return ResolvedPlay(
      cid: cid,
      videos: videos,
      audio: audio,
      durationSeconds: duration != null ? duration ~/ 1000 : 0,
    );
  }

  DashStream _parseStream(Map raw) {
    final id = (raw['id'] as num?)?.toInt() ?? 0;
    return DashStream(
      id: id,
      baseUrl: (raw['baseUrl'] ?? raw['base_url'] ?? '') as String,
      bandwidth: (raw['bandwidth'] as num?)?.toInt() ?? 0,
      codecs: raw['codecs'] as String? ?? '',
      width: (raw['width'] as num?)?.toInt() ?? 0,
      height: (raw['height'] as num?)?.toInt() ?? 0,
      backupUrls:
          ((raw['backupUrl'] ?? raw['backup_url']) as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  // ---------------- 评论 ----------------

  /// 读取评论主列表。[oid] 是视频 aid；[mode] 3=最热 2=最新。
  /// [next] 为分页游标，0 表示第一页。
  Future<CommentPage> fetchComments(
    int oid, {
    int mode = 3,
    int next = 0,
    int ps = 20,
  }) async {
    final res = await _dio.get(
      'https://api.bilibili.com/x/v2/reply/main',
      queryParameters: {
        'type': 1,
        'oid': oid,
        'mode': mode,
        'next': next,
        'ps': ps,
      },
      options: Options(headers: headers),
    );
    if (res.data['code'] != 0) {
      throw Exception('获取评论失败：${res.data['message'] ?? res.data['code']}');
    }
    final data = res.data['data'] as Map? ?? {};
    final cursor = data['cursor'] as Map? ?? {};
    // 置顶评论（top_replies）排在最前并标记 isTop。
    final topRaws = (data['top_replies'] as List?) ?? const [];
    final topItems = topRaws
        .whereType<Map>()
        .map((m) => _parseComment(m, isTop: true))
        .toList();
    final raws = (data['replies'] as List?) ?? const [];
    final items = raws.whereType<Map>().map(_parseComment).toList();
    return CommentPage(
      items: [...topItems, ...items],
      next: (cursor['next'] as num?)?.toInt() ?? 0,
      isEnd: cursor['is_end'] as bool? ?? true,
      total: (cursor['all_count'] as num?)?.toInt() ?? 0,
    );
  }

  CommentItem _parseComment(Map raw, {bool isTop = false}) {
    final member = raw['member'] as Map? ?? {};
    final content = raw['content'] as Map? ?? {};
    final levelInfo = member['level_info'] as Map? ?? {};
    final replyControl = raw['reply_control'] as Map? ?? {};
    final upAction = raw['up_action'] as Map? ?? {};
    // 内置的楼中楼预览（接口直接给了前几条回复）。
    final previewRaws = raw['replies'] as List? ?? const [];
    final preview = previewRaws
        .whereType<Map>()
        .map(_parseComment)
        .whereType<CommentItem>()
        .toList();
    return CommentItem(
      rpid: (raw['rpid'] as num?)?.toInt() ?? 0,
      uname: member['uname'] as String? ?? '未知用户',
      avatar: member['avatar'] as String? ?? '',
      message: content['message'] as String? ?? '',
      ctime: (raw['ctime'] as num?)?.toInt() ?? 0,
      like: (raw['like'] as num?)?.toInt() ?? 0,
      replyCount: (raw['rcount'] as num?)?.toInt() ?? 0,
      mid: (raw['mid'] as num?)?.toInt() ?? 0,
      // up_action 非空表示该评论可以 @UP主 / 是 UP 参与过的评论。
      isUpper: upAction.isNotEmpty && upAction['reply'] == true,
      isTop: isTop,
      level: (levelInfo['current_level'] as num?)?.toInt() ?? 0,
      previewReplies: preview,
      subReplyText: replyControl['sub_reply_entry_text'] as String? ?? '',
      parent: (raw['parent'] as num?)?.toInt() ?? 0,
      officialTime: replyControl['time_desc'] as String?,
    );
  }

  /// 发表评论。[oid] 是视频 aid。需要登录态。
  /// [parent] 非空时表示回复某条评论（楼中楼）。
  ///
  /// 注意：旧接口 `x/v2/reply` 已被 B站下线（返回 405），
  /// 必须用 `x/v2/reply/add`。
  Future<void> sendComment(
    int oid,
    String message, {
    int? parent,
    String? replyTo,
  }) async {
    if (csrfToken.isEmpty) throw Exception('请先登录');
    final res = await _dio.post(
      'https://api.bilibili.com/x/v2/reply/add',
      data: {
        'type': 1,
        'oid': oid,
        'message': message,
        if (parent != null) 'parent': parent,
        if (replyTo != null && replyTo.isNotEmpty) 'reply_to': replyTo,
        'csrf': csrfToken,
      },
      options: Options(
        headers: {
          ...headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        contentType: 'application/x-www-form-urlencoded',
      ),
    );
    if (res.data['code'] != 0) {
      throw Exception('发表评论失败：${res.data['message'] ?? res.data['code']}');
    }
  }

  /// 点赞/取消点赞评论。[action] 1=点赞 0=取消。需要登录态。
  ///
  /// 注意：oid 必须是视频的 aid，rpid 是评论 id，
  /// 只传 rpid 作为 oid 会被 B站判为 -400 请求错误。
  Future<void> likeComment(int oid, int rpid, {required bool like}) async {
    if (csrfToken.isEmpty) throw Exception('请先登录');
    final res = await _dio.post(
      'https://api.bilibili.com/x/v2/reply/action',
      data: {
        'oid': oid,
        'type': 1,
        'rpid': rpid,
        'action': like ? 1 : 0,
        'csrf': csrfToken,
      },
      options: Options(
        headers: {
          ...headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        contentType: 'application/x-www-form-urlencoded',
      ),
    );
    if (res.data['code'] != 0) {
      throw Exception('操作失败：${res.data['message'] ?? res.data['code']}');
    }
  }

  /// 读取某条主评论下的楼中楼回复。
  Future<List<CommentItem>> fetchReplies(
    int oid,
    int root, {
    int pn = 1,
    int ps = 20,
  }) async {
    try {
      final res = await _dio.get(
        'https://api.bilibili.com/x/v2/reply/reply',
        queryParameters: {
          'type': 1,
          'oid': oid,
          'root': root,
          'pn': pn,
          'ps': ps,
        },
        options: Options(headers: headers),
      );
      if (res.data['code'] != 0) return const [];
      final data = res.data['data'] as Map? ?? {};
      final raws = (data['replies'] as List?) ?? const [];
      return raws.whereType<Map>().map(_parseComment).toList();
    } catch (_) {
      return const [];
    }
  }

  /// 点赞楼中楼回复（parent 的楼中楼用 reply_id 而不是 rpid）。
  Future<void> likeSubReply(int oid, int replyId, {required bool like}) async {
    if (csrfToken.isEmpty) throw Exception('请先登录');
    final res = await _dio.post(
      'https://api.bilibili.com/x/v2/reply/action',
      data: {
        'oid': oid,
        'type': 1,
        'rpid': replyId,
        'action': like ? 1 : 0,
        'csrf': csrfToken,
      },
      options: Options(
        headers: {
          ...headers,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        contentType: 'application/x-www-form-urlencoded',
      ),
    );
    if (res.data['code'] != 0) {
      throw Exception('操作失败：${res.data['message'] ?? res.data['code']}');
    }
  }
}
