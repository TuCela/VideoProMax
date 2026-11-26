// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import '../bili/models.dart';
import 'ytdlp.dart';

/// YouTube 首页分类：匿名访问拿不到官方推荐流，用固定主题的搜索结果代替。
class YoutubeCategory {
  const YoutubeCategory(this.name, this.query);

  final String name;
  final String query;
}

const List<YoutubeCategory> kYoutubeCategories = [
  YoutubeCategory('音乐', 'music'),
  YoutubeCategory('游戏', 'gameplay'),
  YoutubeCategory('科技', 'technology review'),
  YoutubeCategory('影视', 'movie trailer'),
  YoutubeCategory('知识', 'documentary'),
  YoutubeCategory('搞笑', 'funny videos'),
  YoutubeCategory('运动', 'sports highlights'),
  YoutubeCategory('美食', 'cooking'),
];

/// 一次解析的结果：详情 + 可选画质。
class YtVideo {
  const YtVideo({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.cover,
    required this.durationSeconds,
    required this.viewCount,
    required this.videos,
    required this.audio,
  });

  final String id;
  final String title;
  final String author;
  final String description;
  final String cover;
  final int durationSeconds;
  final int viewCount;
  final List<DashStream> videos;
  final DashStream? audio;

  VideoItem get item => VideoItem(
    bvid: id,
    title: title,
    author: author,
    cover: cover,
    play: viewCount,
    durationSeconds: durationSeconds,
    pubdate: 0,
  );

  /// 复用 B站那套播放管线（[ResolvedPlay] + DashStream）。
  ResolvedPlay get resolved => ResolvedPlay(
    cid: 'yt',
    videos: videos,
    audio: audio,
    durationSeconds: durationSeconds,
  );
}

/// YouTube 数据访问：搜索、详情、选流，全部经由 yt-dlp。
class YoutubeClient {
  YoutubeClient._();

  static final YoutubeClient instance = YoutubeClient._();

  static const String _watchBase = 'https://www.youtube.com/watch?v=';

  Future<List<VideoItem>> search(String keyword, {int limit = 24}) async {
    final data = await YtDlp.instance.json(
      'ytsearch$limit:$keyword',
      extra: const ['--flat-playlist'],
    );
    final entries = (data['entries'] as List?) ?? const [];
    return entries
        .whereType<Map>()
        .map((raw) => _item(raw.cast<String, dynamic>()))
        .whereType<VideoItem>()
        .toList();
  }

  Future<YtVideo> video(String id) async {
    final data = await YtDlp.instance.json(
      '$_watchBase$id',
      extra: const ['--no-playlist'],
    );
    final rawFormats = (data['formats'] as List?) ?? const [];
    final formats = rawFormats.whereType<Map>().map((e) {
      return e.cast<String, dynamic>();
    }).toList();
    final videos = _pickVideos(formats);
    if (videos.isEmpty) {
      throw YtDlpException('该视频没有可播放的画面（可能是直播或会员内容）');
    }
    return YtVideo(
      id: data['id'] as String? ?? id,
      title: (data['title'] as String? ?? '').trim(),
      author:
          (data['uploader'] as String? ??
                  data['channel'] as String? ??
                  '')
              .trim(),
      description: (data['description'] as String? ?? '').trim(),
      cover: _thumbnail(data),
      durationSeconds: (data['duration'] as num?)?.toInt() ?? 0,
      viewCount: (data['view_count'] as num?)?.toInt() ?? 0,
      videos: videos,
      audio: _pickAudio(formats),
    );
  }

  VideoItem? _item(Map<String, dynamic> raw) {
    final id = (raw['id'] as String? ?? '').trim();
    if (id.isEmpty) return null;
    final title = (raw['title'] as String? ?? '').trim();
    final thumbs = (raw['thumbnails'] as List?) ?? const [];
    var cover = (raw['thumbnail'] as String? ?? '').trim();
    if (cover.isEmpty && thumbs.isNotEmpty) {
      cover = (thumbs.last as Map)['url'] as String? ?? '';
    }
    return VideoItem(
      bvid: id,
      title: title.isEmpty ? '(无标题)' : title,
      author:
          (raw['uploader'] as String? ??
                  raw['channel'] as String? ??
                  '')
              .trim(),
      cover: cover,
      play: (raw['view_count'] as num?)?.toInt() ?? 0,
      durationSeconds: (raw['duration'] as num?)?.toInt() ?? 0,
      pubdate: 0,
    );
  }

  String _thumbnail(Map<String, dynamic> data) {
    final thumbs = (data['thumbnails'] as List?) ?? const [];
    if (thumbs.isNotEmpty) {
      return (thumbs.last as Map)['url'] as String? ?? '';
    }
    return (data['thumbnail'] as String? ?? '').trim();
  }

  /// 每个分辨率只保留一条：优先 H.264（硬解兼容性最好），其次 AV1、VP9，
  /// 同编码取码率最高的一条。HLS（m3u8）在这里跳过，直接用直链。
  List<DashStream> _pickVideos(List<Map<String, dynamic>> formats) {
    final byHeight = <int, DashStream>{};
    for (final format in formats) {
      final url = format['url'] as String? ?? '';
      final codec = format['vcodec'] as String? ?? 'none';
      final protocol = format['protocol'] as String? ?? '';
      final height = (format['height'] as num?)?.toInt() ?? 0;
      if (url.isEmpty || codec == 'none' || height <= 0) continue;
      if (protocol.startsWith('m3u8')) continue;
      final bandwidth = ((format['tbr'] as num?)?.toDouble() ?? 0) * 1000;
      final stream = DashStream(
        id: height,
        baseUrl: url,
        bandwidth: bandwidth.round(),
        codecs: codec,
        width: (format['width'] as num?)?.toInt() ?? 0,
        height: height,
        labelOverride: '${height}P · ${_codecName(codec)}',
      );
      final existing = byHeight[height];
      if (existing == null) {
        byHeight[height] = stream;
        continue;
      }
      final rank = _codecRank(codec);
      final existingRank = _codecRank(existing.codecs);
      if (rank < existingRank ||
          (rank == existingRank && bandwidth > existing.bandwidth)) {
        byHeight[height] = stream;
      }
    }
    final list = byHeight.values.toList()
      ..sort((a, b) => b.height.compareTo(a.height));
    return list;
  }

  DashStream? _pickAudio(List<Map<String, dynamic>> formats) {
    DashStream? best;
    var bestRank = 99;
    for (final format in formats) {
      final url = format['url'] as String? ?? '';
      final codec = format['acodec'] as String? ?? 'none';
      final protocol = format['protocol'] as String? ?? '';
      if (url.isEmpty || codec == 'none' || protocol.startsWith('m3u8')) {
        continue;
      }
      // m4a 兼容性最好；没有时退到 opus，mpv 也能解。
      final rank = codec.startsWith('mp4a') ? 0 : 1;
      final abr = (format['abr'] as num?)?.toDouble() ?? 0;
      if (rank < bestRank ||
          (rank == bestRank &&
              abr > (best?.bandwidth ?? 0) / 1000)) {
        bestRank = rank;
        best = DashStream(
          id: 0,
          baseUrl: url,
          bandwidth: (abr * 1000).round(),
          codecs: codec,
          width: 0,
          height: 0,
          labelOverride: '音频 · ${_codecName(codec)}',
        );
      }
    }
    return best;
  }

  int _codecRank(String codec) {
    if (codec.startsWith('avc1')) return 0;
    if (codec.startsWith('av01')) return 1;
    if (codec.startsWith('vp9') || codec.startsWith('vp09')) return 2;
    return 3;
  }

  String _codecName(String codec) {
    if (codec.startsWith('avc1')) return 'H.264';
    if (codec.startsWith('hev1') || codec.startsWith('hvc1')) return 'H.265';
    if (codec.startsWith('av01')) return 'AV1';
    if (codec.startsWith('vp9') || codec.startsWith('vp09')) return 'VP9';
    if (codec.startsWith('mp4a')) return 'AAC';
    if (codec.startsWith('opus')) return 'Opus';
    return codec;
  }
}
