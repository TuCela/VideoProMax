// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
show
        Clipboard,
        ClipboardData,
        HardwareKeyboard,
        KeyDownEvent,
        KeyRepeatEvent,
        KeyEvent,
        LogicalKeyboardKey;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../app/app_destination.dart';
import '../bili/auth.dart';
import '../bili/client.dart';
import '../bili/download_service.dart';
import '../bili/download_store.dart';
import '../bili/history.dart';
import '../bili/models.dart';
import '../bili/prefs.dart';
import 'category_bar.dart';
import 'comments_panel.dart';
import 'danmaku_bridge.dart';
import 'danmaku_dialogs.dart';
import 'download_dialog.dart';
import 'danmaku_layer.dart';
import 'download_page.dart';
import 'episode_panel.dart';
import 'font_settings.dart';
import 'fullscreen_window.dart';
import 'history_view.dart';
import 'home_header.dart';
import 'login_dialog.dart';
import 'pip_window.dart';
import 'play_url_bar.dart';
import 'player_controls.dart';
// 只复用这里的 UploaderChip；PlayerToolbar 已从页面移除（控制栏已覆盖其功能）。
import 'player_toolbar.dart';
import 'results_list.dart';
import 'search_filter_bar.dart';
import 'space_page.dart';

/// 首页分区数据见 `category_bar.dart`。
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.destination,
    this.prefs,
    this.onDownloadCountChanged,
  });

  final ValueNotifier<AppDestination>? destination;
  final AppPrefs? prefs;
  final ValueChanged<int>? onDownloadCountChanged;

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final BiliClient _client = BiliClient();
  late final BiliAuth _auth = BiliAuth(_client);
  late final Player _player;
  late final VideoController _videoController;
  final TextEditingController _searchCtrl = TextEditingController();
  final List<StreamSubscription<dynamic>> _subs = [];

  List<VideoItem> _items = const [];
  bool _searching = false;
  String? _message;

  /// 0 = 推荐流；1..n = 分区；-1 = 搜索结果
  int _feedIndex = 0;
  bool _feedLoading = false;

  /// 自动续页：当前页码与是否还有更多。
  int _feedPage = 1;
  bool _feedHasMore = true;
  String _feedKeyword = '';

  /// 搜索结果筛选条件（排序 / 时长 / 分区）。
  SearchFilter _searchFilter = const SearchFilter();

  /// 当前视频源平台：bili / youtube / other。
  String _platform = 'bili';

  VideoItem? _current;
  ResolvedPlay? _play;
  DashStream? _stream;
  bool _resolving = false;
  bool _switching = false;

  VideoDetail? _detail;
  String _detailBvid = '';
  String? _currentCid;
  String? _currentPart;
  PgcSeason? _pgcSeason;
  int? _currentEpId;
  int? _preferredQn;

  List<HistoryEntry> _cloudHistory = const [];
  DateTime _cloudFetchedAt = DateTime.fromMillisecondsSinceEpoch(0);
  int? _currentAid;
  int? _currentReportCid;
  DateTime _lastCloudReportAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _showEpisodes = false;
  /// 详情区当前 Tab：0 = 简介，1 = 评论（选集交给播放器右侧常驻侧栏）。
  int _detailTab = 1;

  /// 长简介是否已展开。
  bool _descExpanded = false;
  bool _seasonTab = false;
  bool _episodeDesc = false;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  int _bufferTargetSeconds = 60;

  final HistoryStore _history = HistoryStore();

  /// 下载：记录存储 + 后台服务 + 当前页（0=主页，1=下载页，2=UP主首页，3=历史）
  final DownloadStore _downloadStore = DownloadStore();
  late final DownloadService _downloadService;
  int _page = 0;

  /// 当前打开的 UP 主空间 mid（0 表示未打开）。
  int _upMid = 0;
  bool _localPlaying = false;
  String _localTitle = '';

  /// 本地播放时的文件路径（显示在播放链接条上）。
  String _localFilePath = '';
  DateTime _lastSavedAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _resumeNote;
  Timer? _noteTimer;

  /// 当前视频流的主/备线路与卡顿重试状态
  List<String> _streamUrls = const [];
  int _streamUrlIndex = 0;
  Timer? _stallTimer;
  double _rate = 1.0;
  static const List<double> _rates = [1.0, 1.25, 1.5, 2.0, 0.75];

  late final AppPrefs _prefs = widget.prefs ?? AppPrefs();
  List<DanmakuItem> _danmaku = const [];
  String _danmakuCid = '';
  bool _danmakuOn = true;
  double _dmOpacity = 0.85;
  double _dmScale = 1.0;
  double _dmSpeed = 1.0;
  double _dmArea = 0.5;
  int _fitIndex = 0;
  bool _pipMode = false;
  bool _playing = false;
  String _currentBvid = '';
  final ScrollController _pageScroll = ScrollController();

  /// 左侧视频列表的滚动控制器（用于触底自动续页）。
  final ScrollController _listScroll = ScrollController();

  /// 铺满模式：隐藏顶栏与侧栏，让播放器占满软件窗口（非系统全屏）。
  final ValueNotifier<bool> _theaterMode = ValueNotifier<bool>(false);

  /// 左侧视频列表默认宽度，可拖动分隔条调整。
  final ValueNotifier<double> _leftWidth = ValueNotifier<double>(390);

  /// 搜索结果栏是否收起（收起后播放器占满，左侧只留「展开」按钮）。
  final ValueNotifier<bool> _resultsCollapsed = ValueNotifier<bool>(false);

  /// 收起动画是否已经结束。结束后彻底移除左栏，避免边缘残影。
  bool _resultsFullyCollapsed = false;

  @override
  void initState() {
    super.initState();
    _downloadStore.addListener(_onDownloadStoreChanged);
    widget.destination?.addListener(_onDestinationChanged);
    // 如果初始就是收起态（例如后续改成默认收起），展开按钮要立即可见。
    _resultsFullyCollapsed = _resultsCollapsed.value;
    // 全局键盘监听：全屏时按 Esc 退出。用 HardwareKeyboard 而非页面级
    // Focus，因为 media_kit 的软件内全屏是新 push 的路由，页面 Focus 收不到。
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _listScroll.addListener(_onListScroll);
    _player = Player(
      configuration: const PlayerConfiguration(bufferSize: 32 * 1024 * 1024),
    );
    _videoController = VideoController(_player);
    DanmakuBridge.instance.player = _player;
    // 下载服务：全局单例 + 加载历史记录（中断的任务标记为失败）。
    DownloadService.initialize(client: _client, store: _downloadStore);
    _downloadService = DownloadService.instance;
    unawaited(_downloadStore.load());
    _subs.add(
_player.stream.position.listen((value) {
        if (mounted) setState(() => _position = value);
        DanmakuBridge.instance.updatePlaybackTime(value, _duration);
        _recordProgress();
      }),
    );
    _subs.add(
      _player.stream.duration.listen((value) {
        if (mounted) setState(() => _duration = value);
        DanmakuBridge.instance.updatePlaybackTime(_position, value);
      }),
    );
    _subs.add(
      _player.stream.buffer.listen((value) {
        if (mounted) setState(() => _buffer = value);
      }),
    );
    _subs.add(
      _player.stream.playing.listen((playing) {
        if (mounted) setState(() => _playing = playing);
        // 同步给全屏控制栏按钮（全屏路由里 home_page 的 setState 传不进去）
        DanmakuBridge.instance.playing.value = playing;
        if (!playing) _recordProgress(force: true);
      }),
    );
    _subs.add(
      _player.stream.volume.listen((volume) {
        // 音量变化（滑块/滚轮/静音）同步给全屏控制栏音量按钮
        DanmakuBridge.instance.volume.value = volume;
      }),
    );
    _configureMpv();
    _boot();
  }

  /// 给 mpv 设置更抗抖动的缓存策略，并强制用音频时钟同步
  Future<void> _configureMpv() async {
    try {
      final native = _player.platform as dynamic;
      await native.setProperty('video-sync', 'audio');
      await native.setProperty('cache', 'yes');
      await native.setProperty('demuxer-max-bytes', '268435456');
      await native.setProperty('demuxer-readahead-secs', '60');
      // B站 DASH 音频是独立地址，靠 audio-add 挂到主文件上。
      // mpv 的 audio-add 不会继承单个 Media 的 httpHeaders，缺 Referer/UA
      // 会被 CDN 拒绝，表现为「视频在播但没声音」。设为全局默认头即可解决。
      await native.setProperty('http-header-fields', _mpvHeaderFields());
    } catch (_) {
      // 设置失败时用 mpv 默认值
    }
  }

  Future<void> _applyBufferSeconds(int seconds) async {
    final value = seconds.clamp(5, 120);
    _bufferTargetSeconds = value;
    _prefs.bufferSeconds = value;
    if (mounted) setState(() {});
    try {
      final native = _player.platform as dynamic;
      final maxBytes = value <= 60
          ? 268435456
          : value <= 90
          ? 402653184
          : 536870912;
      await native.setProperty('demuxer-max-bytes', maxBytes);
      await native.setProperty('demuxer-readahead-secs', value);
    } catch (_) {}
  }

  void _previewBufferTarget(int seconds) {
    unawaited(_applyBufferSeconds(seconds));
  }

  Future<void> _saveBufferTarget() async {
    await _prefs.save();
  }

  /// mpv 全局请求头（逗号分隔的 `Name: value` 列表）。
  String _mpvHeaderFields() => _client.streamHeaders.entries
      .map((e) => '${e.key}: ${e.value}')
      .join(',');

  Future<void> _boot() async {
    await _client.initVisitor();
    await _auth.load();
    await _history.load();
    await _prefs.load();
    // 登录后 Cookie 才可用，补写一次全局头，audio-add 才能带全凭据。
    try {
      await (_player.platform as dynamic).setProperty(
        'http-header-fields',
        _mpvHeaderFields(),
      );
    } catch (_) {}
    final fontOverride = int.tryParse(
      Platform.environment['VIDEOHUB_FONT_DELTA'] ?? '',
    );
    FontSettings.instance.restore(fontOverride ?? _prefs.fontDelta);
    _danmakuOn = _prefs.danmakuOn;
    _dmOpacity = _prefs.danmakuOpacity;
    _dmScale = _prefs.danmakuScale;
    _dmSpeed = _prefs.danmakuSpeed;
    _dmArea = _prefs.danmakuArea;
    final fitIndex = ['contain', 'cover', 'fill'].indexOf(_prefs.fit);
    _fitIndex = fitIndex < 0 ? 0 : fitIndex;
    _platform = _prefs.platform;
    await _applyBufferSeconds(_prefs.bufferSeconds);
    try {
      await _player.setVolume(_prefs.volume);
    } catch (_) {}
    unawaited(_refreshCloudHistory(force: true));
    if (mounted) setState(() {});
    await _loadFeed(0);
    final initialDestination = widget.destination?.value;
    if (initialDestination == AppDestination.downloads) {
      setState(() => _page = 1);
    } else if (initialDestination == AppDestination.history) {
      setState(() => _page = 3);
    } else if (initialDestination == AppDestination.space) {
      _openOwnSpace();
    }

    // 无交互自检：设置 VIDEOHUB_SMOKE=BV号 启动后自动播放并把状态写进临时日志
    final smoke = Platform.environment['VIDEOHUB_SMOKE'];
    if (smoke != null && smoke.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      await _playVideo(
        VideoItem(
          bvid: smoke,
          title: 'smoke',
          author: '',
          cover: '',
          play: 0,
          durationSeconds: 0,
          pubdate: 0,
        ),
      );
      _startSmokeLog();
    }
  }

  Future<String> _prop(String name) async {
    try {
      final value = await (_player.platform as dynamic).getProperty(name);
      return value?.toString() ?? '-';
    } catch (_) {
      return '-';
    }
  }

  void _startSmokeLog() {
    final file = File('${Directory.systemTemp.path}\\videohub-smoke.log');
    try {
      file.writeAsStringSync(
        'start history=${_history.entries.length} note=${_resumeNote ?? "-"}\n',
      );
    } catch (_) {}
    var ticks = 0;
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      ticks += 1;
      try {
        final tracks = _player.state.tracks;
        final speed = await _prop('speed');
        final audioPts = await _prop('audio-pts');
        final videoPts = await _prop('video-pts');
        final ao = await _prop('current-ao');
        final paused = await _prop('paused');
        final cacheSpeed = await _prop('cache-speed');
        final eof = await _prop('eof-reached');
        final volProp = await _prop('volume');
        final muteProp = await _prop('mute');
        file.writeAsStringSync(
          '[$ticks] pos=${_position.inMilliseconds} dur=${_duration.inMilliseconds} '
          'buf=${_buffer.inSeconds}s speed=$speed aPts=$audioPts vPts=$videoPts ao=$ao '
          'vol=$volProp mute=$muteProp '
          'paused=$paused cacheSpeed=$cacheSpeed eof=$eof '
          'v=${tracks.video.length} a=${tracks.audio.length} '
          'dm=${_danmaku.length} dmCid=$_danmakuCid dmOn=$_danmakuOn '
          'msg=${_message ?? "-"}\n',
          mode: FileMode.append,
        );
      } catch (_) {}
      if (ticks >= 20) timer.cancel();
    });
  }

  /// 加载推荐流 / 分区内容（[append]=true 时续页追加）
  Future<void> _loadFeed(int index, {bool append = false}) async {
    if (_feedLoading) return;
    if (_platform != 'bili') {
      setState(() {
        _items = [];
        _feedHasMore = false;
        _message = _unsupportedSourceMessage();
      });
      return;
    }
    if (append && !_feedHasMore) return;
    final page = append ? _feedPage + 1 : 1;
    if (!append) {
      _theaterMode.value = false;
      _expandResultsPanel();
    }
    setState(() {
      if (!append) _page = 0;
      _feedIndex = index;
      _feedLoading = true;
      if (!append) _message = null;
    });
    try {
      List<VideoItem> items;
      if (index == 0) {
        items = await _client.fetchRecommend(freshIdx: page);
      } else {
        final category = kAllBiliCategories[index - 1];
        items = category.seasonType != null
            ? await _client.fetchBangumiFeed(category.seasonType!, page: page)
            : await _client.fetchCategory(category.rid, page: page);
      }
      if (!mounted) return;
      setState(() {
        _feedPage = page;
        if (append) {
          // 去重追加（按 bvid）。
          final existing = _items.map((e) => e.bvid).toSet();
          final fresh = items.where((e) => !existing.contains(e.bvid)).toList();
          _items = [..._items, ...fresh];
          // 拉回来的全是重复内容 => 到底了，继续翻也只会拿到同样的数据。
          _feedHasMore = items.isNotEmpty && fresh.isNotEmpty;
        } else {
          _items = items;
          _feedHasMore = items.isNotEmpty;
          if (items.isEmpty) {
            _message = index == 0 ? '推荐加载失败，稍后再试' : '这个分区暂时没有拉到内容';
          }
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '加载失败：$error');
    } finally {
      if (mounted) setState(() => _feedLoading = false);
    }
  }

  Future<void> _search({bool append = false}) async {
    if (_feedLoading) return;
    final keyword = _searchCtrl.text.trim();
    if (keyword.isEmpty) return;
    if (_platform != 'bili') {
      setState(() {
        _page = 0;
        _feedIndex = -1;
        _items = [];
        _feedHasMore = false;
        _message = _unsupportedSourceMessage();
      });
      return;
    }
    if (append && !_feedHasMore) return;
    final page = append ? _feedPage + 1 : 1;
    if (!append) {
      _theaterMode.value = false;
      _expandResultsPanel();
    }
    setState(() {
      _searching = true;
      _feedLoading = true;
      if (!append) {
        _page = 0;
        _feedIndex = -1;
        _feedKeyword = keyword;
        _message = null;
      }
    });
    try {
      final items = await _client.search(
        _feedKeyword,
        page: page,
        order: _searchFilter.order,
        duration: _searchFilter.duration,
        tids: _searchFilter.tid,
      );
      if (!mounted) return;
      setState(() {
        _feedPage = page;
        if (append) {
          final existing = _items.map((e) => e.bvid).toSet();
          final fresh = items.where((e) => !existing.contains(e.bvid)).toList();
          _items = [..._items, ...fresh];
          _feedHasMore = items.isNotEmpty && fresh.isNotEmpty;
        } else {
          _items = items;
          _feedHasMore = items.isNotEmpty;
          if (items.isEmpty) _message = '没有搜到结果，换个关键词试试';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = '搜索失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
          _feedLoading = false;
        });
      }
    }
  }

  String _unsupportedSourceMessage() => switch (_platform) {
    'youtube' => 'YouTube 视频源即将接入，敬请期待',
    'other' => '其他平台视频源即将接入，敬请期待',
    _ => '哔哩哔哩视频源即将接入，敬请期待',
  };

  void _changePlatform(String code) {
    if (code == _platform) return;
    setState(() => _platform = code);
    _prefs.platform = code;
    unawaited(_prefs.save());
    if (code == 'bili') {
      unawaited(_loadFeed(_feedIndex < 0 ? 0 : _feedIndex));
    } else {
      setState(() {
        _items = [];
        _feedHasMore = false;
        _message = _unsupportedSourceMessage();
      });
    }
  }

  /// 从其他分区/页面返回最近一次搜索结果。
  void _restoreSearchResults() {
    if (_feedKeyword.isEmpty) {
      _snack('还没有搜索结果，请先搜索');
      return;
    }
    _theaterMode.value = false;
    _searchCtrl.text = _feedKeyword;
    if (mounted) setState(() => _page = 0);
    widget.destination?.value = AppDestination.home;
    unawaited(_search());
  }

  /// 「UP首页」按钮：默认打开当前登录账号的空间。
  void _openOwnSpace() {
    if (!_auth.isLoggedIn) {
      _snack('请先扫码登录，再打开 UP 首页');
      widget.destination?.value = AppDestination.home;
      return;
    }
    // 优先回到最后一次从视频下方点进去的 UP；没有记录才用登录账号。
    final ownMid = int.tryParse(_auth.user?.mid ?? '') ?? 0;
    final mid = _prefs.lastUpMid > 0 ? _prefs.lastUpMid : ownMid;
    if (mid <= 0) {
      _snack('请先扫码登录，再打开 UP 首页');
      widget.destination?.value = AppDestination.home;
      return;
    }
    _openUpSpace(mid, remember: false);
  }

  /// 打开指定 UP 主空间（视频下方头像/名字也走这里）。
  void _openUpSpace(int mid, {bool remember = true}) {
    if (mid <= 0) {
      _snack('这个视频没有 UP 主信息');
      return;
    }
    if (remember) {
      // 记住用户主动点开的 UP，之后点「UP首页」优先回到这里。
      _prefs.lastUpMid = mid;
      unawaited(_prefs.save());
    }
    _theaterMode.value = false;
    DanmakuBridge.instance.episodePanelVisible.value = false;
    // mid 改变时 ValueKey 会重建 SpacePage；同 mid 再次点击则保持当前页。
    if (mounted)
      setState(() {
        _upMid = mid;
        _page = 2;
      });
    widget.destination?.value = AppDestination.space;
  }

  /// 收起/展开左侧搜索结果栏。
  void _toggleResultsCollapsed() {
    if (_resultsCollapsed.value) {
      // 展开：先把左栏重新挂载，动画才能从 0 平滑回到原宽度。
      setState(() => _resultsFullyCollapsed = false);
      _resultsCollapsed.value = false;
    } else {
      _resultsCollapsed.value = true;
    }
  }

  /// 搜索/切分区时自动展开结果栏。
  void _expandResultsPanel() {
    if (!_resultsCollapsed.value && !_resultsFullyCollapsed) return;
    setState(() => _resultsFullyCollapsed = false);
    _resultsCollapsed.value = false;
  }

  /// 列表滚到底自动续页（推荐/分区/搜索结果共用）。
  void _onListScroll() {
    if (_feedLoading || !_feedHasMore) return;
    // 左侧视频列表滚到底才续页（播放器详情的滚动不触发）。
    if (!_listScroll.hasClients) return;
    final pos = _listScroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      if (_feedIndex == -1) {
        unawaited(_search(append: true));
      } else {
        unawaited(_loadFeed(_feedIndex, append: true));
      }
    }
  }

  /// 点击搜索结果：取详情（分P/合集）后播放；[cid] 可指定分P，[startAt] 用于续播
  Future<void> _playVideo(
    VideoItem item, {
    String? cid,
    Duration startAt = Duration.zero,
    String? part,
  }) async {
    if (_localPlaying && mounted) setState(() => _localPlaying = false);
    _recordProgress(force: true);
    if (_auth.isLoggedIn) await _refreshCloudHistory();
    if (item.seasonId != null) {
      await _playSeason(item, startAt: startAt);
      return;
    }
    setState(() {
      _current = item;
      _detail = null;
      _detailBvid = '';
      _currentCid = null;
      _currentPart = null;
      _seasonTab = false;
      _pgcSeason = null;
      _currentEpId = null;
      _currentAid = null;
      _currentReportCid = null;
      _resolving = true;
      _message = null;
      _play = null;
      _stream = null;
    });
    VideoDetail? detail;
    try {
      detail = await _client.fetchDetail(item.bvid);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _detailBvid = item.bvid;
      });
    } catch (_) {
      // 详情拿不到也尝试直接播第一P
    }
    try {
      VideoPage? page;
      if (detail != null) {
        if (cid != null) {
          for (final candidate in detail.pages) {
            if (candidate.cid == cid) {
              page = candidate;
              break;
            }
          }
        }
        page ??= detail.pages.isNotEmpty ? detail.pages.first : null;
      }
      final targetCid =
          cid ?? page?.cid ?? (detail != null ? detail.cid : null);
      await _loadPlay(
        item,
        targetCid,
        startAt,
        part: part ?? page?.title,
        aid: detail?.aid,
      );
    } catch (error) {
      if (mounted) setState(() => _message = '播放源解析失败：$error');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  /// 解析并播放某个 cid，保留当前画质偏好
  Future<void> _loadPlay(
    VideoItem item,
    String? cid,
    Duration startAt, {
    String? part,
    int? aid,
  }) async {
    final data = await _client.resolve(item.bvid, cid: cid);
    if (!mounted) return;
    final stream = _pickDefault(data.videos, preferQn: _preferredQn);
    var resumeAt = startAt;
    if (resumeAt <= Duration.zero) {
      final saved = _savedEntry('v:${item.bvid}:${data.cid}');
      if (saved != null && saved.positionSeconds >= 5) {
        final total = data.durationSeconds;
        if (total <= 0 || saved.positionSeconds < total - 3) {
          resumeAt = Duration(seconds: saved.positionSeconds);
          _showResumeNote(resumeAt);
        }
      }
    }
    setState(() {
      _current = item;
      _currentCid = data.cid;
      _currentPart = part;
      _currentAid = aid ?? _currentAid;
      _currentReportCid = int.tryParse(data.cid);
      _currentBvid = item.bvid;
      _play = data;
      _stream = stream;
    });
    unawaited(_loadDanmaku(data.cid));
    await _openStream(stream, data.audio, resumeAt);
  }

  /// 本地与云端取进度更靠前的一条
  HistoryEntry? _savedEntry(String key) {
    final local = _history.find(key);
    HistoryEntry? cloud;
    for (final entry in _cloudHistory) {
      if (entry.key == key) {
        cloud = entry;
        break;
      }
    }
    if (local == null) return cloud;
    if (cloud == null) return local;
    return cloud.positionSeconds > local.positionSeconds ? cloud : local;
  }

  /// 切换分P
  Future<void> _switchPage(VideoPage page) async {
    final item = _current;
    if (item == null || _resolving || _currentCid == page.cid) return;
    _recordProgress(force: true);
    setState(() {
      _resolving = true;
      _message = null;
    });
    try {
      await _loadPlay(
        item,
        page.cid,
        Duration.zero,
        part: page.title,
        aid: _currentAid,
      );
    } catch (error) {
      if (mounted) setState(() => _message = '切换分P失败：$error');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  /// 播放合集里的某一集（可能是另一个视频）
  Future<void> _playEpisode(SeasonEpisode episode) async {
    if (_resolving) return;
    if (_current?.bvid == episode.bvid && _currentCid == episode.cid) return;
    _recordProgress(force: true);
    setState(() {
      _resolving = true;
      _message = null;
      _pgcSeason = null;
      _currentEpId = null;
    });
    try {
      var aid = _currentAid;
      if (episode.bvid != _detailBvid) {
        final detail = await _client.fetchDetail(episode.bvid);
        if (!mounted) return;
        aid = detail.aid;
        setState(() {
          _detail = detail;
          _detailBvid = episode.bvid;
          _seasonTab = false;
        });
      }
      await _loadPlay(
        VideoItem(
          bvid: episode.bvid,
          title: episode.title,
          author: _current?.author ?? '',
          cover: _current?.cover ?? '',
          play: 0,
          durationSeconds: episode.durationSeconds,
          pubdate: 0,
        ),
        episode.cid,
        Duration.zero,
        part: episode.title,
        aid: aid,
      );
    } catch (error) {
      if (mounted) setState(() => _message = '切换选集失败：$error');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  /// 播放版权内容（番剧/国创/综艺）的一季；[epId] 指定集，[startAt] 用于续播
  Future<void> _playSeason(
    VideoItem item, {
    int? epId,
    Duration startAt = Duration.zero,
  }) async {
    if (_localPlaying && mounted) setState(() => _localPlaying = false);
    _recordProgress(force: true);
    if (_auth.isLoggedIn) await _refreshCloudHistory();
    final seasonId = item.seasonId;
    if (seasonId == null) return;
    setState(() {
      _current = item;
      _detail = null;
      _detailBvid = '';
      _pgcSeason = null;
      _currentEpId = null;
      _currentCid = null;
      _currentPart = null;
      _currentAid = null;
      _currentReportCid = null;
      _resolving = true;
      _message = null;
      _play = null;
      _stream = null;
    });
    try {
      final season = await _client.fetchSeason(seasonId: seasonId);
      if (!mounted) return;
      setState(() => _pgcSeason = season);
      if (season.episodes.isEmpty) {
        throw Exception('这一季没有可播放的剧集');
      }
      var target = season.episodes.first;
      if (epId != null) {
        for (final episode in season.episodes) {
          if (episode.epId == epId) {
            target = episode;
            break;
          }
        }
      }
      await _playPgcEpisode(target, initial: true, startAt: startAt);
    } catch (error) {
      if (mounted) setState(() => _message = '加载剧集失败：$error');
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _playPgcEpisode(
    PgcEpisode episode, {
    bool initial = false,
    Duration startAt = Duration.zero,
  }) async {
    if (_localPlaying && mounted) setState(() => _localPlaying = false);
    if (!initial) {
      setState(() {
        _resolving = true;
        _message = null;
      });
    }
    try {
      final data = await _client.resolvePgc(episode.epId);
      if (!mounted) return;
      final stream = _pickDefault(data.videos, preferQn: _preferredQn);
      var resumeAt = startAt;
      if (resumeAt <= Duration.zero) {
        final saved = _savedEntry('ep:${episode.epId}');
        if (saved != null && saved.positionSeconds >= 5) {
          final total = data.durationSeconds;
          if (total <= 0 || saved.positionSeconds < total - 3) {
            resumeAt = Duration(seconds: saved.positionSeconds);
            _showResumeNote(resumeAt);
          }
        }
      }
      setState(() {
        _currentEpId = episode.epId;
        _currentCid = data.cid;
        _currentPart = episode.title;
        _currentAid = episode.aid > 0 ? episode.aid : _currentAid;
        _currentReportCid = int.tryParse(episode.cid);
        _currentBvid = episode.bvid;
        _play = data;
        _stream = stream;
      });
      unawaited(_loadDanmaku(episode.cid));
      await _openStream(stream, data.audio, resumeAt);
    } catch (error) {
      if (mounted) setState(() => _message = '播放失败：$error');
    } finally {
      if (!initial && mounted) setState(() => _resolving = false);
    }
  }

  Future<void> _switchEpisode(PgcEpisode episode) async {
    if (_resolving || _currentEpId == episode.epId) return;
    _recordProgress(force: true);
    await _playPgcEpisode(episode);
  }

  /// 打开一路视频 + 挂上独立的音频流（B站 DASH 音视频分离）
  Future<void> _openStream(
    DashStream video,
    DashStream? audio,
    Duration startAt,
  ) async {
    // 主线路 + 备用线路；主线路不稳定时看门狗会自动切下一个。
    _streamUrls = [video.baseUrl, ...video.backupUrls];
    _streamUrlIndex = 0;
    await _openStreamAtCurrent(video, audio, startAt);
    _watchStall(video, audio, startAt);
  }

  /// 按 [_streamUrlIndex] 指向的线路打开媒体。
  Future<void> _openStreamAtCurrent(
    DashStream video,
    DashStream? audio,
    Duration startAt,
  ) async {
    final url = _streamUrls[_streamUrlIndex];
    await _player.open(
      Media(url, httpHeaders: _client.streamHeaders),
      play: false,
    );
    if (audio != null) {
      try {
        final platform = _player.platform;
        await (platform as dynamic).command([
          'audio-add',
          audio.baseUrl,
          'select',
        ]);
        // audio-add 失败时 media_kit 只把错误写进日志，不会抛异常，
        // 所以主动校验一次 aid；没选中音轨就让 mpv 自动选。
        final aid = await (platform as dynamic).getProperty('aid');
        if (aid == null || '$aid' == 'no') {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          await (platform as dynamic).setProperty('aid', 'auto');
        }
      } catch (_) {
        // 音轨挂载失败时 mpv 会尝试从视频流里取音频
      }
    }
    if (_rate != 1.0) {
      await _player.setRate(_rate);
    }
    await _player.play();
    // 必须等起播后再 seek：open/audio-add/play 都会把位置重置到 0，
    // 且文件刚 load 时 mpv 可能直接丢弃 seek，所以要校验并重试。
    if (startAt > const Duration(seconds: 1)) {
      for (var attempt = 0; attempt < 5; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        try {
          await _player.seek(startAt);
        } catch (_) {}
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final current = _player.state.position;
        if ((current - startAt).abs() <= const Duration(seconds: 5)) break;
      }
    }
  }

  /// 卡顿看门狗：B站主 CDN 偶尔给截断/极慢的流，4 秒还没缓冲就换备用线路。
  void _watchStall(DashStream video, DashStream? audio, Duration startAt) {
    _stallTimer?.cancel();
    var checks = 0;
    _stallTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      checks += 1;
      // 已正常起播：撤掉看门狗。
      if (_player.state.position > const Duration(milliseconds: 500) ||
          _buffer > const Duration(seconds: 2)) {
        timer.cancel();
        return;
      }
      // 试完所有线路还不行：提示用户并停止。
      if (_streamUrlIndex >= _streamUrls.length - 1) {
        timer.cancel();
        if (mounted) {
          _snack('当前线路加载失败，请换一个视频或稍后重试');
        }
        return;
      }
      if (checks < 2) return; // 至少给 4 秒
      timer.cancel();
      _streamUrlIndex += 1;
      if (mounted) {
        setState(() => _message = '主线路较慢，正在切换备用线路…');
      }
      try {
        await _openStreamAtCurrent(video, audio, startAt);
      } catch (_) {
        if (mounted) _snack('备用线路也加载失败');
      }
    });
  }

  /// 从链接条手工输入网址：支持 BV / av 号、b23.tv 短链和 ?p= 分P。
  Future<void> _playFromUrl(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    try {
      final source = await _client.expandShortUrl(text);
      VideoItem? item;
      var bvid = _client.parseBvid(source);
      if (bvid == null) {
        var aid = _client.parseAid(source);
        aid ??= RegExp(r'^\d+$').hasMatch(source) ? int.tryParse(source) : null;
        if (aid != null) {
          item = await _client.fetchVideoItem('$aid');
          bvid = item.bvid;
        }
      }
      if (bvid == null) {
        _snack('没有识别到视频，请粘贴 BV / av 链接或 b23.tv 短链');
        return;
      }
      item ??= await _client.fetchVideoItem(bvid);

      // ?p=2 指定分P：取对应 cid，让 _playVideo 直接跳到该 P。
      String? cid;
      final p = RegExp(r'[?&]p=(\d+)').firstMatch(source);
      if (p != null) {
        final index = (int.tryParse(p.group(1) ?? '') ?? 1) - 1;
        final detail = await _client.fetchDetail(bvid);
        if (index >= 0 && index < detail.pages.length) {
          cid = detail.pages[index].cid;
        }
      }
      await _playVideo(item, cid: cid);
    } catch (e) {
      _snack('打开视频失败：$e');
    }
  }

  /// 播放器上方显示的网页版链接：BV 优先，退化到 av 号。
  String get _videoWebUrl {
    if (_currentBvid.isNotEmpty) {
      return 'https://www.bilibili.com/video/$_currentBvid';
    }
    final aid = _currentAid;
    if (aid != null && aid > 0) {
      return 'https://www.bilibili.com/video/av$aid';
    }
    return '';
  }

  /// 默认画质：当前视频可选画质里最高的一档。
  /// 先比分辨率，再比码率，最后比 qn id；不再沿用上次选择或限死 1080P。
  DashStream _pickDefault(List<DashStream> videos, {int? preferQn}) {
    final sorted = List<DashStream>.from(videos)
      ..sort((a, b) {
        final byHeight = b.height.compareTo(a.height);
        if (byHeight != 0) return byHeight;
        final byBandwidth = b.bandwidth.compareTo(a.bandwidth);
        if (byBandwidth != 0) return byBandwidth;
        return b.id.compareTo(a.id);
      });
    return sorted.first;
  }

  Future<void> _switchQuality(DashStream stream) async {
    if (_switching || _stream?.id == stream.id || _play == null) return;
    final resumeAt = _position;
    setState(() {
      _switching = true;
      _preferredQn = stream.id;
      _stream = stream;
    });
    try {
      await _openStream(stream, _play!.audio, resumeAt);
    } catch (error) {
      if (mounted) setState(() => _message = '切换画质失败：$error');
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  /// 每 5 秒写一次进度；force 用于暂停 / 切集 / 关闭时立即落盘
  void _recordProgress({bool force = false}) {
    final current = _current;
    final play = _play;
    if (current == null || play == null || _duration.inSeconds <= 0) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastSavedAt).inSeconds < 5) return;
    final position = _position.inSeconds;
    if (position < 5) return;
    _lastSavedAt = now;
    final finished = _duration.inSeconds - position <= 3;
    final isPgc = _currentEpId != null;
    final entry = HistoryEntry(
      key: isPgc ? 'ep:$_currentEpId' : 'v:${current.bvid}:${play.cid}',
      kind: isPgc ? 'pgc' : 'video',
      bvid: current.bvid,
      cid: play.cid,
      epId: _currentEpId,
      seasonId: current.seasonId,
      title: current.title,
      partTitle: _currentPart ?? '',
      cover: current.cover,
      positionSeconds: finished ? 0 : position,
      durationSeconds: _duration.inSeconds,
      updatedAt: now.millisecondsSinceEpoch,
    );
    unawaited(_history.upsert(entry));
    _reportCloudProgress(force: force);
  }

  /// 把进度上报到 B站，手机端/网页端即可接着看
  void _reportCloudProgress({bool force = false}) {
    if (!_auth.isLoggedIn) return;
    final aid = _currentAid;
    final cid = _currentReportCid;
    if (aid == null || cid == null || aid <= 0 || cid <= 0) return;
    if (_duration.inSeconds <= 0) return;
    final position = _position.inSeconds;
    if (position < 10 || position >= _duration.inSeconds - 2) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastCloudReportAt).inSeconds < 15) return;
    _lastCloudReportAt = now;
    unawaited(
      _client.reportProgress(aid: aid, cid: cid, progressSeconds: position),
    );
  }

  /// 拉取云端历史，与本地合并用于续播与历史面板
  Future<void> _refreshCloudHistory({bool force = false}) async {
    if (!_auth.isLoggedIn) {
      if (_cloudHistory.isNotEmpty && mounted) {
        setState(() => _cloudHistory = const []);
      }
      return;
    }
    if (!force && DateTime.now().difference(_cloudFetchedAt).inSeconds < 60) {
      return;
    }
    try {
      final items = await _client.fetchCloudHistory();
      _cloudFetchedAt = DateTime.now();
      if (!mounted) return;
      setState(() {
        _cloudHistory = items
            .map(
              (item) => HistoryEntry(
                key: item.kind == 'pgc'
                    ? 'ep:${item.epId}'
                    : 'v:${item.bvid}:${item.cid}',
                kind: item.kind,
                bvid: item.bvid,
                cid: item.cid,
                epId: item.epId,
                title: item.title,
                partTitle: item.partTitle,
                cover: item.cover,
                positionSeconds: item.progressSeconds,
                durationSeconds: item.durationSeconds,
                updatedAt: item.viewAt * 1000,
                fromCloud: true,
              ),
            )
            .toList();
      });
    } catch (_) {
      // 云端拉不到就只用本地历史
    }
  }

  void _showResumeNote(Duration at) {
    _noteTimer?.cancel();
    _stallTimer?.cancel();
    if (!mounted) return;
    setState(() => _resumeNote = '已从 ${_fmt(at)} 续播');
    _noteTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _resumeNote = null);
    });
  }

  Future<void> _resumeFromHistory(HistoryEntry entry) async {
    _goHome();
    final startAt = Duration(seconds: entry.positionSeconds);
    if (entry.kind == 'pgc' && entry.epId != null) {
      var seasonId = entry.seasonId;
      if (seasonId == null) {
        // 云端记录只有 epid，先反查所属季
        try {
          final season = await _client.fetchSeason(epId: entry.epId);
          seasonId = season.seasonId;
        } catch (error) {
          if (mounted) setState(() => _message = '续播失败：$error');
          return;
        }
      }
      final item = VideoItem(
        bvid: entry.bvid,
        title: entry.title,
        author: '',
        cover: entry.cover,
        play: 0,
        durationSeconds: entry.durationSeconds,
        pubdate: 0,
        seasonId: seasonId,
      );
      await _playSeason(item, epId: entry.epId, startAt: startAt);
      return;
    }
    await _playVideo(
      VideoItem(
        bvid: entry.bvid,
        title: entry.title,
        author: '',
        cover: entry.cover,
        play: 0,
        durationSeconds: entry.durationSeconds,
        pubdate: 0,
      ),
      cid: entry.cid.isEmpty ? null : entry.cid,
      startAt: startAt,
      part: entry.partTitle.isEmpty ? null : entry.partTitle,
    );
  }

  Future<void> _closePlayer() async {
    _recordProgress(force: true);
    _noteTimer?.cancel();
    if (_pipMode) {
      PipWindow.exit();
      _pipMode = false;
    }
    try {
      await _player.stop();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _current = null;
      _play = null;
      _stream = null;
      _detail = null;
      _detailBvid = '';
      _pgcSeason = null;
      _currentCid = null;
      _currentEpId = null;
      _currentPart = null;
      _currentAid = null;
      _currentReportCid = null;
      _currentBvid = '';
      _danmaku = const [];
      _danmakuCid = '';
      _resumeNote = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _buffer = Duration.zero;
    });
  }

  Future<void> _cycleRate() async {
    final index = _rates.indexOf(_rate);
    final next = _rates[(index + 1) % _rates.length];
    setState(() => _rate = next);
    DanmakuBridge.instance.rate.value = next;
    try {
      await _player.setRate(next);
    } catch (_) {}
  }

  BoxFit get _fit =>
      const [BoxFit.contain, BoxFit.cover, BoxFit.fill][_fitIndex];

  /// 切换弹幕开关：同步页面状态、全局 notifier 与偏好。
  void _toggleDanmaku() {
    setState(() => _danmakuOn = !_danmakuOn);
    DanmakuBridge.instance.danmakuOn.value = _danmakuOn;
    _prefs.danmakuOn = _danmakuOn;
    unawaited(_prefs.save());
  }

  /// 切换画面比例并持久化。
  void _setFit(int index) {
    setState(() => _fitIndex = index);
    _prefs.fit = const ['contain', 'cover', 'fill'][index];
    unawaited(_prefs.save());
  }

  Future<void> _loadDanmaku(String cid) async {
    if (cid.isEmpty || cid == _danmakuCid) return;
    _danmakuCid = cid;
    if (mounted) setState(() => _danmaku = const []);
    try {
      final items = await _client.fetchDanmaku(cid);
      if (!mounted || _danmakuCid != cid) return;
      setState(() => _danmaku = items);
    } catch (_) {
      // 弹幕拉不到不影响播放
    }
  }

  Future<void> _sendDanmaku() async {
    final aid = _currentAid;
    final cid = _currentReportCid;
    if (aid == null || cid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('当前内容暂不支持发送弹幕')));
      return;
    }
    final text = await showDialog<String>(
      context: context,
      builder: (_) => DanmakuInputDialog(position: _position),
    );
    if (text == null || text.trim().isEmpty) return;
    final error = await _client.sendDanmaku(
      aid: aid,
      cid: '$cid',
      bvid: _currentBvid,
      text: text.trim(),
      progressMs: _position.inMilliseconds,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error ?? '弹幕已发送')));
    if (error == null) {
      final item = DanmakuItem(
        time: _position.inMilliseconds / 1000,
        mode: 1,
        fontSize: 25,
        color: 0xFFFFFF,
        text: text.trim(),
      );
      setState(() {
        _danmaku = [..._danmaku, item]
          ..sort((a, b) => a.time.compareTo(b.time));
      });
    }
  }

  /// 打开批量下载对话框。根据当前播放类型列出可下载剧集。
  Future<void> _openDownload() async {
    final current = _current;
    final play = _play;
    if (current == null) {
      _snack('请先选择一个视频');
      return;
    }

    final items = <DownloadItem>[];
    final season = _pgcSeason;
    if (_currentEpId != null && season != null) {
      for (final ep in season.episodes) {
        items.add(
          DownloadItem(
            bvid: ep.bvid,
            cid: ep.cid,
            title: ep.title,
            epId: ep.epId,
          ),
        );
      }
    } else {
      final detail = _detail;
      if (detail != null && detail.pages.length > 1) {
        for (final page in detail.pages) {
          items.add(
            DownloadItem(
              bvid: current.bvid,
              cid: page.cid,
              title: 'P' + page.page.toString() + ' ' + page.title,
            ),
          );
        }
      } else if (detail != null && detail.hasSeason) {
        for (final ep in detail.episodes) {
          items.add(DownloadItem(bvid: ep.bvid, cid: ep.cid, title: ep.title));
        }
      } else {
        items.add(
          DownloadItem(
            bvid: current.bvid,
            cid: _currentCid ?? detail?.cid ?? '',
            title: current.title,
            cover: current.cover,
          ),
        );
      }
    }
    if (items.isEmpty) {
      _snack('没有可下载的内容');
      return;
    }

    final qualities = play?.videos ?? const <DashStream>[];
    var initialQuality = _prefs.downloadQualityId;
    if (initialQuality < 0 || !qualities.any((q) => q.id == initialQuality)) {
      initialQuality = qualities.isNotEmpty ? qualities.first.id : 64;
    }
    final pickerQualities = qualities.isNotEmpty
        ? qualities
        : <DashStream>[
            DashStream(
              id: 64,
              baseUrl: '',
              bandwidth: 0,
              codecs: 'avc1',
              width: 0,
              height: 0,
            ),
          ];

    if (!mounted) return;
    final result = await showDialog<DownloadPickResult>(
      context: context,
      builder: (_) => DownloadPickerDialog(
        items: items,
        qualities: pickerQualities,
        initialQualityId: initialQuality,
        downloadDir: _downloadService.downloadDir.path,
        initialThreads: _prefs.downloadThreads,
        initialSpeedLimitMB: _prefs.downloadSpeedLimit ~/ (1024 * 1024),
      ),
    );
    if (result == null || !mounted) return;

    _prefs.downloadQualityId = result.qualityId;
    _prefs.downloadThreads = result.threads;
    _prefs.downloadSpeedLimit = result.speedLimitMB * 1024 * 1024;
    _downloadService.threads = result.threads;
    _downloadService.speedLimit = _prefs.downloadSpeedLimit;
    unawaited(_prefs.save());

    String qualityLabel = '画质 ' + result.qualityId.toString();
    for (final q in qualities) {
      if (q.id == result.qualityId) {
        qualityLabel = q.label;
        break;
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    var added = 0;
    for (final item in result.items) {
      final key = item.epId != null
          ? 'ep:' + item.epId.toString()
          : 'v:' + item.bvid + ':' + item.cid;
      final record = DownloadRecord(
        key: key,
        bvid: item.bvid,
        cid: item.cid,
        epId: item.epId,
        title: item.title,
        cover: item.cover,
        qualityId: result.qualityId,
        qualityLabel: qualityLabel,
        status: DlStatus.pending,
        progress: 0,
        message: '等待下载…',
        createdAt: now + added,
      );
      if (_downloadService.enqueue(record)) added++;
    }
    if (added > 0) {
      _snack('已添加 ' + added.toString() + ' 个下载任务，正在后台下载');
      if (mounted) setState(() => _page = 1);
    } else {
      _snack('这些视频已在下载列表中');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _openDanmakuSettings() async {
    final result = await showDialog<DanmakuSettings>(
      context: context,
      builder: (_) => DanmakuSettingsDialog(
        enabled: _danmakuOn,
        opacity: _dmOpacity,
        scale: _dmScale,
        speed: _dmSpeed,
        area: _dmArea,
      ),
    );
    if (result == null) return;
    setState(() {
      _danmakuOn = result.enabled;
      _dmOpacity = result.opacity;
      _dmScale = result.scale;
      _dmSpeed = result.speed;
      _dmArea = result.area;
    });
    _prefs
      ..danmakuOn = result.enabled
      ..danmakuOpacity = result.opacity
      ..danmakuScale = result.scale
      ..danmakuSpeed = result.speed
      ..danmakuArea = result.area;
    unawaited(_prefs.save());
  }

  Future<void> _togglePip() async {
    if (_pipMode) {
      PipWindow.exit();
      setState(() => _pipMode = false);
      return;
    }
    final ok = PipWindow.enter();
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('当前窗口无法进入画中画')));
      return;
    }
    setState(() => _pipMode = true);
  }

  /// 点击「选集」：在视频窗口内弹出浮层（窗口/全屏/铺满模式共用）。
  void _openEpisodePanel() {
    if (!_episodeData().available) {
      _snack('当前视频没有选集');
      return;
    }
    DanmakuBridge.instance.episodePanelVisible.value = true;
  }

  List<PgcEpisode> get _episodeList => _pgcSeason?.episodes ?? const [];

  int _currentEpisodeIndex() {
    if (_currentEpId != null) {
      return _episodeList.indexWhere((item) => item.epId == _currentEpId);
    }
    final detail = _detail;
    if (detail == null) return -1;
    final pageIndex = detail.pages.indexWhere(
      (page) => page.cid == _currentCid,
    );
    if (detail.pages.length > 1 && pageIndex >= 0) return pageIndex;
    if (detail.hasSeason) {
      return detail.episodes.indexWhere(
        (item) => item.bvid == _current?.bvid && item.cid == _currentCid,
      );
    }
    return -1;
  }

  int _episodeCount() {
    if (_currentEpId != null) return _episodeList.length;
    final detail = _detail;
    if (detail == null) return 0;
    if (detail.pages.length > 1) return detail.pages.length;
    return detail.hasSeason ? detail.episodes.length : 0;
  }

  bool _canStep(int delta) {
    final index = _currentEpisodeIndex();
    if (index < 0) return false;
    final next = index + delta;
    return next >= 0 && next < _episodeCount();
  }

  Future<void> _step(int delta) async {
    final index = _currentEpisodeIndex();
    if (index < 0) return;
    final next = index + delta;
    if (_currentEpId != null) {
      if (next < 0 || next >= _episodeList.length) return;
      await _switchEpisode(_episodeList[next]);
      return;
    }
    final detail = _detail;
    if (detail == null) return;
    if (detail.pages.length > 1) {
      if (next < 0 || next >= detail.pages.length) return;
      await _switchPage(detail.pages[next]);
    } else if (detail.hasSeason) {
      if (next < 0 || next >= detail.episodes.length) return;
      await _playEpisode(detail.episodes[next]);
    }
  }

  Future<void> _login() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => LoginDialog(auth: _auth),
    );
    if (ok == true && mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.destination?.removeListener(_onDestinationChanged);
    _downloadStore.removeListener(_onDownloadStoreChanged);
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _recordProgress(force: true);
    _noteTimer?.cancel();
    if (_pipMode) PipWindow.exit();
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
    _searchCtrl.dispose();
    _listScroll.removeListener(_onListScroll);
    _pageScroll.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  void _onDownloadStoreChanged() {
    widget.onDownloadCountChanged?.call(
      _downloadStore.records.where((record) => record.isActive).length,
    );
    if (mounted) setState(() {});
  }

  void _onDestinationChanged() {
    final destination = widget.destination?.value;
    if (!mounted ||
        destination == null ||
        destination == AppDestination.settings) {
      return;
    }
    switch (destination) {
      case AppDestination.home:
        setState(() => _page = 0);
      case AppDestination.history:
        setState(() => _page = 3);
        unawaited(_refreshCloudHistory(force: true));
      case AppDestination.downloads:
        setState(() {
          _page = 1;
          _localPlaying = false;
        });
      case AppDestination.space:
        _openOwnSpace();
      case AppDestination.settings:
        break;
    }
  }

  void _goHome() {
    if (mounted) setState(() => _page = 0);
    widget.destination?.value = AppDestination.home;
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }

  @override
  Widget build(BuildContext context) {
    // 把弹幕状态推给桥接层：自定义 Video controls 在窗口与全屏下
    // 都会读取它，从而让弹幕在软件内全屏时也不丢失。
    DanmakuBridge.instance.update(
      items: _danmaku,
      cid: _danmakuCid,
      enabled: _danmakuOn,
      opacity: _dmOpacity,
      fontScale: _dmScale,
      speed: _dmSpeed,
      area: _dmArea,
    );
    DanmakuBridge.instance.danmakuOn.value = _danmakuOn;
    // 把当前分P/剧集推给全局桥接层，窗口与全屏的选集浮层共用。
    _pushEpisodesToBridge();
    if (_pipMode) return _buildPipView();
    return Scaffold(
      body: ValueListenableBuilder<bool>(
        valueListenable: _theaterMode,
        builder: (_, theater, __) {
          if (theater) {
            // 铺满模式：只留播放器占满整个软件窗口。
            return SizedBox.expand(child: _buildPlayer());
          }
          return Column(
            children: [
              HomeHeader(
                searchController: _searchCtrl,
                searching: _searching,
                onSearch: () => unawaited(_search()),
                loggedIn: _auth.isLoggedIn,
                userName: _auth.user?.name ?? '',
                avatarUrl: _auth.user?.avatar ?? '',
                onLogin: () => unawaited(_login()),
                onLogout: () async {
                  await _auth.logout();
                  if (mounted) setState(() {});
                },
                onFontChanged: () {
                  _prefs.fontDelta = FontSettings.instance.delta.value;
                  unawaited(_prefs.save());
                },
                onSettings: () =>
                    widget.destination?.value = AppDestination.settings,
                onUpSpace: _openOwnSpace,
                platform: _platform,
                onPlatformChanged: _changePlatform,
              ),
              if (_page == 0) ...[
                CategoryBar(
                  page: _page,
                  feedIndex: _feedIndex,
                  onSelectFeed: (index) => unawaited(_loadFeed(index)),
                  onRestoreSearch: _restoreSearchResults,
                ),
              ],
              if (_page == 1)
                _buildDownloadPage()
              else if (_page == 2)
                Expanded(
                  child: SpacePage(
                    key: ValueKey('space-$_upMid'),
                    client: _client,
                    mid: _upMid,
                    onPlay: (item) {
                      widget.destination?.value = AppDestination.home;
                      setState(() => _page = 0);
                      unawaited(_playVideo(item));
                    },
                  ),
                )
              else if (_page == 3)
                Expanded(
                  child: HistoryView(
                    store: _history,
                    cloudEntries: _cloudHistory,
                    onSelect: (entry) => unawaited(_resumeFromHistory(entry)),
                  ),
                )
              else
                Expanded(
                  child: _buildSplitRow(
                    left: ResultsList(
                      title: _feedIndex == -1
                          ? '搜索结果'
                          : (_feedIndex == 0
                                ? '推荐'
                                : kAllBiliCategories[_feedIndex - 1].name),
                      items: _items,
                      loading: _searching || _feedLoading,
                      feedLoading: _feedLoading,
                      hasMore: _feedHasMore,
                      message: _message,
                      scrollController: _listScroll,
                      onTap: (item) => unawaited(_playVideo(item)),
                      onCollapse: _toggleResultsCollapsed,
                      onRefresh: _feedIndex >= 0
                          ? () => unawaited(_loadFeed(_feedIndex))
                          : null,
                      currentBvid: _current?.bvid,
                      currentSeasonId: _current?.seasonId,
                      showFilter: _feedIndex == -1,
                      filter: _searchFilter,
                      onFilterChanged: (f) {
                        setState(() => _searchFilter = f);
                        unawaited(_search());
                      },
                    ),
                    right: _buildPlayer(),
                    collapsible: true,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 字体大小调节按钮组：− / 当前值 / +，每次 ±1px。
  /// 可拖动的分栏布局：左侧列表 + 分隔条 + 右侧播放器。
  /// [collapsible] 为 true 时支持把左侧搜索结果栏收起到最左边。
  Widget _buildSplitRow({
    required Widget left,
    required Widget right,
    bool collapsible = false,
  }) {
    return ValueListenableBuilder<double>(
      valueListenable: _leftWidth,
      builder: (_, requestedWidth, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: _resultsCollapsed,
          builder: (_, collapsed, __) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final total = constraints.maxWidth;
                final panelWidth = requestedWidth
                    .clamp(total * 0.24, total * 0.45)
                    .toDouble();
                final panelHeight = constraints.hasBoundedHeight
                    ? constraints.maxHeight
                    : 640.0;
                final panel = SizedBox(
                  width: panelWidth + 6,
                  height: panelHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: panelWidth, child: left),
                      _buildDragDivider(totalWidth: total),
                    ],
                  ),
                );
                if (!collapsible) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      panel,
                      Expanded(child: right),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: collapsed ? 0.0 : 1.0),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOutCubic,
                      onEnd: () {
                        if (!mounted) return;
                        if (_resultsCollapsed.value &&
                            !_resultsFullyCollapsed) {
                          setState(() => _resultsFullyCollapsed = true);
                        }
                      },
                      builder: (_, factor, child) {
                        if (collapsed && _resultsFullyCollapsed) {
                          return const SizedBox.shrink();
                        }
                        return SizeTransition(
                          sizeFactor: AlwaysStoppedAnimation<double>(factor),
                          axis: Axis.horizontal,
                          axisAlignment: -1.0,
                          child: child,
                        );
                      },
                      child: panel,
                    ),
                    Expanded(child: right),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// 收起后嵌入「网页链接」条最左侧的「展开」按钮，字号与标题一致。
  Widget _buildInlineExpandButton() {
    return InkWell(
      onTap: _toggleResultsCollapsed,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF20242C),
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '展开',
              style: TextStyle(fontSize: 13, color: Color(0xFF9FB0FF)),
            ),
            SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 16, color: Color(0xFF9FB0FF)),
          ],
        ),
      ),
    );
  }

  /// 可拖动的竖直分隔条。
  Widget _buildDragDivider({required double totalWidth}) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {},
        onHorizontalDragUpdate: (details) {
          if (totalWidth <= 0) return;
          final next = (_leftWidth.value + details.delta.dx)
              .clamp(totalWidth * 0.24, totalWidth * 0.45)
              .toDouble();
          _leftWidth.value = next;
        },
        child: Container(
          width: 6,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Container(width: 1, color: const Color(0xFF2A2E36)),
        ),
      ),
    );
  }

  /// 下载管理页：左侧任务列表（筛选），右侧复用播放器。
  Widget _buildDownloadPage() {
    return Expanded(
      child: _buildSplitRow(
        left: DownloadList(
          store: _downloadStore,
          service: _downloadService,
          onPlay: _playDownloaded,
        ),
        right: _buildPlayer(),
      ),
    );
  }

  /// 播放已下载到本地的视频文件。
  Future<void> _playDownloaded(DownloadRecord record) async {
    final file = File(record.outputPath);
    if (!file.existsSync()) {
      _snack('文件不存在：${record.outputPath}');
      return;
    }
    _recordProgress(force: true);
    if (mounted) {
      setState(() {
        _localPlaying = true;
        _localTitle = record.title;
        _localFilePath = file.path;
        _danmakuOn = false;
      });
    }
    try {
      await _player.open(Media(file.path), play: true);
    } catch (e) {
      if (mounted) _snack('播放失败：$e');
    }
  }

  /// 选集数据快照：右侧栏、控制栏浮层共用同一份数据。
  ({
    List<EpisodeEntry> entries,
    String summary,
    bool hasTabs,
    bool seasonTab,
    bool desc,
    bool available,
  })
  _episodeData() {
    final pgc = _pgcSeason;
    final detail = _detail;
    if (pgc == null &&
        (detail == null || (!detail.hasPages && !detail.hasSeason))) {
      return (
        entries: const [],
        summary: '',
        hasTabs: false,
        seasonTab: false,
        desc: _episodeDesc,
        available: false,
      );
    }

    var hasTabs = false;
    var useSeason = false;
    if (pgc == null && detail != null) {
      hasTabs = detail.hasPages && detail.hasSeason;
      useSeason = detail.hasPages
          ? (detail.hasSeason && _seasonTab)
          : detail.hasSeason;
    }

    final entries = <EpisodeEntry>[];
    if (pgc != null) {
      for (var i = 0; i < pgc.episodes.length; i++) {
        final episode = pgc.episodes[i];
        entries.add(
          EpisodeEntry(
            label: episode.badge.isNotEmpty ? episode.badge : '${i + 1}',
            title: episode.title,
            meta: formatSeconds(episode.durationSeconds),
            playing: _currentEpId == episode.epId,
            onTap: () => _switchEpisode(episode),
          ),
        );
      }
    } else if (useSeason) {
      for (var i = 0; i < detail!.episodes.length; i++) {
        final episode = detail.episodes[i];
        entries.add(
          EpisodeEntry(
            label: '${i + 1}',
            title: episode.title,
            meta: episode.sectionTitle,
            playing:
                _current?.bvid == episode.bvid && _currentCid == episode.cid,
            onTap: () => _playEpisode(episode),
          ),
        );
      }
    } else {
      for (final page in detail!.pages) {
        entries.add(
          EpisodeEntry(
            label: 'P${page.page}',
            title: page.title,
            meta: page.durationText,
            playing: _currentCid == page.cid,
            onTap: () => _switchPage(page),
          ),
        );
      }
    }

    final summary = pgc != null
        ? '共 ${pgc.episodes.length} 话'
              '${pgc.subtitle.isNotEmpty ? ' · ${pgc.subtitle}' : ''}'
        : (useSeason
              ? '合集 · ${detail!.seasonTitle ?? ''}'
              : '共 ${detail!.pages.length} P');
    return (
      entries: _episodeDesc ? entries.reversed.toList() : entries,
      summary: summary,
      hasTabs: hasTabs,
      seasonTab: _seasonTab,
      desc: _episodeDesc,
      available: true,
    );
  }

  /// 把选集数据推给桥接层；只有数据变化才通知，避免播放进度刷新时反复重建。
  void _pushEpisodesToBridge() {
    final data = _episodeData();
    final key =
        '${data.summary}|${data.hasTabs}|${data.seasonTab}|'
        '${data.desc}|${data.entries.map((e) => '${e.label}/${e.title}/${e.playing}').join(';')}';
    DanmakuBridge.instance.updateEpisodes(
      key: key,
      entries: data.entries,
      summary: data.summary,
      hasTabs: data.hasTabs,
      seasonTab: data.seasonTab,
      desc: data.desc,
      onToggleTab: () {
        if (mounted) setState(() => _seasonTab = !_seasonTab);
      },
      onToggleDesc: () {
        if (mounted) setState(() => _episodeDesc = !_episodeDesc);
      },
    );
  }

  /// 选集列表项。
  Widget _buildPipView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Video(controller: _videoController, fit: _fit),
                if (_danmakuOn && _danmaku.isNotEmpty)
                  Positioned.fill(
                    child: DanmakuLayer(
                      key: ValueKey('pip-$_danmakuCid'),
                      items: _danmaku,
                      position: _position,
                      playing: _playing,
                      enabled: _danmakuOn,
                      opacity: _dmOpacity,
                      fontScale: _dmScale,
                      speed: _dmSpeed,
                      area: _dmArea,
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Row(
              children: [
                _pipButton(Icons.fullscreen_exit, '退出画中画', _togglePip),
                const SizedBox(width: 4),
                _pipButton(Icons.close, '关闭播放', _closePlayer),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pipButton(IconData icon, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  /// 控制栏音量按钮：图标随音量变化，悬停弹出竖直滑块，点击静音切换。
  Future<void> _toggleSoftwareFullscreen() async {
    final state = DanmakuBridge.instance.videoState;
    if (state == null) return;
    try {
      if (state.isFullscreen()) {
        await state.exitFullscreen();
      } else {
        await state.enterFullscreen();
      }
    } catch (_) {}
  }

  void _toggleGlobalFullscreen() {
    GlobalFullscreen.toggle();
  }

  void _toggleTheaterMode() {
    _theaterMode.value = !_theaterMode.value;
  }

  /// 全局按键处理：Esc 退出全屏（软件内全屏优先，其次全局全屏/铺满）。
  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;
    // 软件内全屏：VideoState 在全屏路由里会被更新为对应实例。
    final state = DanmakuBridge.instance.videoState;
    if (state != null && state.isFullscreen()) {
      unawaited(state.exitFullscreen());
      return true; // 已消费
    }
    // 全局全屏：退出系统级全屏。
    if (GlobalFullscreen.stateNotifier.value) {
      GlobalFullscreen.exit();
      return true;
    }
    // 铺满窗口模式：恢复原布局。
    if (_theaterMode.value) {
      _theaterMode.value = false;
      return true;
    }
    return false;
  }

  /// 用控制栏按钮构建播放器控制主题。
  MaterialDesktopVideoControlsThemeData _controlTheme() {
    return playerControlTheme(
      buildControlBarButtons(
        player: _player,
        canPrev: _canStep(-1),
        canNext: _canStep(1),
        onPrev: () => unawaited(_step(-1)),
        onNext: () => unawaited(_step(1)),
        onOpenEpisodes: _openEpisodePanel,
        onToggleDanmaku: _toggleDanmaku,
        onSendDanmaku: _sendDanmaku,
        onDanmakuSettings: _openDanmakuSettings,
        pipMode: _pipMode,
        onTogglePip: _togglePip,
        onCycleRate: _cycleRate,
fitIndex: _fitIndex,
        onFitChanged: _setFit,
        theaterMode: _theaterMode,
        onToggleTheater: _toggleTheaterMode,
        onGlobalFullscreen: _toggleGlobalFullscreen,
        onFullscreen: _toggleSoftwareFullscreen,
      ),
    );
  }

  /// 视频下方的 UP 主信息：头像 + 名字，点击进入对应 UP 空间首页。
  /// 视频下方的 UP 主信息：头像 + 名字，点击进入对应 UP 空间首页。
  Widget _buildUploaderChip() {
    final item = _current;
    if (item == null) return const SizedBox.shrink();
    final mid = (_detail?.ownerMid ?? 0) > 0 ? _detail!.ownerMid : item.mid;
    final face = (_detail?.ownerFace ?? '').isNotEmpty
        ? _detail!.ownerFace
        : item.face;
    return UploaderChip(
      author: item.author,
      face: face,
      onTap: () => _openUpSpace(mid),
    );
  }

  /// 简介 Tab：长文本默认折叠 6 行，可展开/收起。
  Widget _buildDescription() {
    final text = (_detail?.description.isNotEmpty ?? false)
        ? _detail!.description
        : '暂无视频简介';
    final expandable = text.length > 220 || '\n'.allMatches(text).length > 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          maxLines: expandable && !_descExpanded ? 6 : null,
          overflow: expandable && !_descExpanded
              ? TextOverflow.ellipsis
              : null,
          style: const TextStyle(
            fontSize: 12,
            height: 1.7,
            color: Color(0xFF9AA0AA),
          ),
        ),
        if (expandable)
          TextButton(
            onPressed: () => setState(() => _descExpanded = !_descExpanded),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 26),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: const Color(0xFF9FB0FF),
            ),
            child: Text(
              _descExpanded ? '收起' : '展开全部',
              style: const TextStyle(fontSize: 11),
            ),
          ),
      ],
    );
  }

  Widget _buildPlayer() {
    // 本地下载文件播放：复用同一个 Video 与控制栏，只是不走 B站流。
    if (_localPlaying) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlayUrlBar(
            url: _localFilePath,
            label: '本地文件',
            onPlayUrl: _playFromUrl,
          ),
          Expanded(
            child: MaterialDesktopVideoControlsTheme(
              normal: _controlTheme(),
              fullscreen: _controlTheme(),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Video(
                          controller: _videoController,
                          fit: _fit,
                          controls: hubVideoControls,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _localTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFC9CDD4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    final current = _current;
    if (current == null) {
      // 空状态也保留链接输入框，用户一进来就能粘贴网址播放。
      final showExpand = _resultsFullyCollapsed && _page == 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlayUrlBar(
            url: '',
            label: '网页链接',
            leading: showExpand ? _buildInlineExpandButton() : null,
            onPlayUrl: _playFromUrl,
          ),
          const Expanded(
            child: Center(
              child: Text(
                '从左侧选择视频，或在上方粘贴链接回车播放',
                style: TextStyle(fontSize: 12, color: Color(0xFF8B9099)),
              ),
            ),
          ),
        ],
      );
    }
    if (_theaterMode.value) {
      // 铺满模式：单个 Video 占满窗口，控制栏按钮悬浮其上。
      return MaterialDesktopVideoControlsTheme(
        normal: _controlTheme(),
        fullscreen: _controlTheme(),
        child: SizedBox.expand(
          child: Video(
            controller: _videoController,
            fit: _fit,
            controls: hubVideoControls,
          ),
        ),
      );
    }
    // 视频区独立在 ScrollView 之外，避免鼠标滚轮调音量时被页面滚动抢走。
    // 选集从评论区上方移到视频窗口右边：与播放器同高、常驻可见。
    final episodeData = _episodeData();
    final hasEpisodes = episodeData.available;
    final videoRow = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.horizontal(
                    left: const Radius.circular(10),
                    right: hasEpisodes
                        ? Radius.zero
                        : const Radius.circular(10),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: MaterialDesktopVideoControlsTheme(
                  normal: _controlTheme(),
                  fullscreen: _controlTheme(),
                  child: Video(
                    controller: _videoController,
                    fit: _fit,
                    controls: hubVideoControls,
                  ),
                ),
              ),
            ),
            if (hasEpisodes)
              SizedBox(
                // 收起时只保留一条细窄入口，尽量把宽度让给播放器。
                width: _showEpisodes ? 220 : 38,
                child: Padding(
                  padding: EdgeInsets.only(left: _showEpisodes ? 8 : 4),
                  child: EpisodePanel(
                    entries: episodeData.entries,
                    summary: episodeData.summary,
                    hasTabs: episodeData.hasTabs,
                    seasonTab: episodeData.seasonTab,
                    expanded: _showEpisodes,
                    sidebar: true,
                    onToggleExpanded: () =>
                        setState(() => _showEpisodes = !_showEpisodes),
                    onToggleSeasonTab: () =>
                        setState(() => _seasonTab = !_seasonTab),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                current.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _PlayerMoreButton(
              webUrl: _videoWebUrl,
              onDownload: _openDownload,
              onClose: _closePlayer,
            ),
          ],
        ),
        const SizedBox(height: 6),
Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (current.play > 0)
              Text(
                '${_fmtPlayCount(current.play)}播放',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8B9099)),
              ),
            if (_duration > Duration.zero)
              Text(
                '视频 ${_fmt(_duration)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8B9099)),
              ),
            if (_currentPart != null &&
                _currentPart!.isNotEmpty &&
                _currentPart != current.title)
              Text(
                _currentPart!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFF9AA0AA)),
              ),
          ],
        ),
const SizedBox(height: 10),
        Row(
          children: [
            _buildUploaderChip(),
            const SizedBox(width: 8),
            if (_play != null)
              _QualityMenu(
                streams: _play!.videos,
                currentId: _stream?.id,
                onSelected: _switchQuality,
                onAuto: () => _switchQuality(_pickDefault(_play!.videos)),
              ),
            const SizedBox(width: 6),
            _BufferTargetButton(
              value: _bufferTargetSeconds,
              onChanged: _previewBufferTarget,
              onFinished: _saveBufferTarget,
            ),
            if (_buffer > Duration.zero) ...[
              const SizedBox(width: 8),
              Text(
                '缓冲 ${_buffer.inSeconds}s',
                style: TextStyle(
                  fontSize: 10,
                  color: _buffer.inSeconds < 3
                      ? const Color(0xFFFFB86B)
                      : const Color(0xFF657086),
                ),
              ),
            ],
            const Spacer(),
            _ToolChip(
              icon: Icons.download_rounded,
              label: '下载',
              onTap: _openDownload,
            ),
          ],
        ),
        if (_resolving || _switching) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(minHeight: 2),
        ],
        if (_resumeNote != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.play_circle_outline,
                  size: 13,
                  color: Color(0xFF7C93FF),
                ),
                const SizedBox(width: 4),
                Text(
                  _resumeNote!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7C93FF),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            _DetailTab(
              label: '简介',
              active: _detailTab == 0,
              onTap: () => setState(() => _detailTab = 0),
            ),
            const SizedBox(width: 18),
            _DetailTab(
              label: '评论',
              active: _detailTab == 1,
              onTap: () => setState(() => _detailTab = 1),
            ),
            const Spacer(),
          ],
        ),
        const Divider(height: 1, color: Color(0xFF23262D)),
        const SizedBox(height: 10),
if (_detailTab == 0) ...[
          _buildDescription(),
        ] else ...[
          CommentsPanel(
            key: ValueKey('comments-$_currentBvid-${_currentAid ?? 0}'),
            client: _client,
            oid: _currentAid ?? 0,
            isLoggedIn: _auth.isLoggedIn,
            onNeedLogin: _login,
          ),
        ],
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(
            _message!,
            style: const TextStyle(fontSize: 12, color: Color(0xFFFF9A9A)),
          ),
        ],
      ],
    );

    // 收起搜索结果后，整块播放器区域可上下滚动，详情不再被视频高度挤成 0。
    return ValueListenableBuilder<bool>(
      valueListenable: _resultsCollapsed,
      builder: (_, collapsed, __) {
        final isCollapsed = collapsed && _page == 0;
        final showExpand = _resultsFullyCollapsed && _page == 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlayUrlBar(
              url: _videoWebUrl,
              label: '网页链接',
              leading: showExpand ? _buildInlineExpandButton() : null,
              onPlayUrl: _playFromUrl,
            ),
            if (!isCollapsed) ...[
              videoRow,
              Expanded(
                child: SingleChildScrollView(
                  controller: _pageScroll,
                  padding: const EdgeInsets.all(16),
                  child: details,
                ),
              ),
            ] else
              Expanded(
                child: SingleChildScrollView(
                  controller: _pageScroll,
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      videoRow,
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: details,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 播放量缩写：12345 → 1.2万，超过 1 亿用「亿」。
String _fmtPlayCount(int value) {
  String trim(double raw) {
    final text = raw.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  if (value >= 100000000) return '${trim(value / 100000000)}亿';
  if (value >= 10000) return '${trim(value / 10000)}万';
  return '$value';
}

/// 画质下拉：替代原来那一排 ChoiceChip，画质再多也不换行。
class _QualityMenu extends StatelessWidget {
  const _QualityMenu({
    required this.streams,
    required this.currentId,
    required this.onSelected,
    required this.onAuto,
  });

  final List<DashStream> streams;
  final int? currentId;
  final ValueChanged<DashStream> onSelected;
  final VoidCallback onAuto;

  @override
  Widget build(BuildContext context) {
    final label = streams
        .firstWhere(
          (stream) => stream.id == currentId,
          orElse: () => streams.first,
        )
        .label;
    return PopupMenuButton<int>(
      tooltip: '画质',
      color: const Color(0xFF141820),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF2A313E)),
      ),
      onSelected: (value) {
        if (value == -1) {
          onAuto();
          return;
        }
        for (final stream in streams) {
          if (stream.id == value) onSelected(stream);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem<int>(
          value: -1,
          child: Text('自动（最高）', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuDivider(),
        for (final stream in streams)
          PopupMenuItem<int>(
            value: stream.id,
            child: Text(
              '${stream.label}${stream.id == currentId ? '  ✓' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF141820),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF2A2E36)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '画质 $label',
              style: const TextStyle(fontSize: 11, color: Color(0xFFC9CDD4)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 13, color: Color(0xFF6E7480)),
          ],
        ),
      ),
    );
  }
}

/// 详情区工具行的小胶囊按钮（目前只有「下载」）。
class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null
        ? const Color(0xFF4A4F58)
        : const Color(0xFFC9CDD4);
    return Tooltip(
      message: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF141820),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF2A2E36)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 详情区 Tab：下划线指示，替代原来的三等分按钮。
class _DetailTab extends StatelessWidget {
  const _DetailTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.only(bottom: 7),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF5B8CFF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? const Color(0xFF9FB0FF) : const Color(0xFF8B9099),
          ),
        ),
      ),
    );
  }
}

/// 标题右侧「⋯」：复制链接 / 浏览器打开 / 下载视频 / 关闭播放器。
class _PlayerMoreButton extends StatelessWidget {
  const _PlayerMoreButton({
    required this.webUrl,
    required this.onDownload,
    required this.onClose,
  });

  final String webUrl;
  final VoidCallback onDownload;
  final VoidCallback onClose;

  Future<void> _copy(BuildContext context) async {
    final url = webUrl.trim();
    if (url.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('播放链接已复制到剪贴板')),
      );
    }
  }

  Future<void> _openInBrowser() async {
    final url = webUrl.trim();
    if (url.isEmpty) return;
    await Process.start('cmd', ['/c', 'start', '', url], runInShell: true);
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: '更多',
      color: const Color(0xFF141820),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF2A313E)),
      ),
      onSelected: (value) {
        switch (value) {
          case 0:
            unawaited(_copy(context));
          case 1:
            unawaited(_openInBrowser());
          case 2:
            onDownload();
          case 3:
            onClose();
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem<int>(
          value: 0,
          child: Text('复制链接', style: TextStyle(fontSize: 12)),
        ),
        PopupMenuItem<int>(
          value: 1,
          child: Text('在浏览器打开', style: TextStyle(fontSize: 12)),
        ),
        PopupMenuDivider(),
        PopupMenuItem<int>(
          value: 2,
          child: Text('下载视频', style: TextStyle(fontSize: 12)),
        ),
        PopupMenuItem<int>(
          value: 3,
          child: Text('关闭播放器', style: TextStyle(fontSize: 12)),
        ),
      ],
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF141820),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFF2A313E)),
        ),
        child: const Icon(Icons.more_horiz, size: 16, color: Color(0xFFC9CDD4)),
      ),
    );
  }
}

class _BufferTargetButton extends StatelessWidget {
  const _BufferTargetButton({
    required this.value,
    required this.onChanged,
    required this.onFinished,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      tooltip: '调节预缓冲时长',
      color: const Color(0xFF141820),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFF2A313E)),
      ),
      onSelected: (_) => onFinished(),
      onCanceled: onFinished,
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          height: 224,
          padding: EdgeInsets.zero,
          child: SizedBox(
            width: 280,
            child: _BufferTargetPanel(value: value, onChanged: onChanged),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF171A20),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF2A313E)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune, size: 12, color: Color(0xFF9FB0FF)),
            const SizedBox(width: 4),
            Text(
              '预缓冲 ${value}s',
              style: const TextStyle(fontSize: 10, color: Color(0xFFB8CBFF)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BufferTargetPanel extends StatefulWidget {
  const _BufferTargetPanel({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_BufferTargetPanel> createState() => _BufferTargetPanelState();
}

class _BufferTargetPanelState extends State<_BufferTargetPanel> {
  late int _value;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    _controller = TextEditingController(text: '$_value');
  }

  @override
  void didUpdateWidget(covariant _BufferTargetPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _value = widget.value;
      _controller.text = '$_value';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setValue(int seconds) {
    final value = seconds.clamp(5, 120);
    setState(() => _value = value);
    _controller.text = '$value';
    widget.onChanged(value);
  }

  Widget _quickChip(int seconds) {
    final selected = _value == seconds;
    return InkWell(
      onTap: () => _setValue(seconds),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1B2A4A) : const Color(0xFF1A1F29),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? const Color(0xFF385A9F) : const Color(0xFF2A313E),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '${seconds}s',
          style: TextStyle(
            fontSize: 10,
            color: selected ? const Color(0xFFB8CBFF) : const Color(0xFF929BAD),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '预缓冲时长',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _setValue(60),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 26),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFF9FB0FF),
                ),
                child: const Text('恢复默认', style: TextStyle(fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            '提前加载更多视频数据，减少网络波动造成的卡顿。',
            style: TextStyle(fontSize: 10, color: Color(0xFF657086)),
          ),
          const SizedBox(height: 14),
          Slider(
            value: _value.toDouble(),
            min: 5,
            max: 120,
            divisions: 115,
            label: '$_value 秒',
            activeColor: const Color(0xFF5B8CFF),
            inactiveColor: const Color(0xFF2A313E),
            onChanged: (value) => _setValue(value.round()),
          ),
          const Row(
            children: [
              Text(
                '5s',
                style: TextStyle(fontSize: 9, color: Color(0xFF657086)),
              ),
              Spacer(),
              Text(
                '120s',
                style: TextStyle(fontSize: 9, color: Color(0xFF657086)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                '精确秒数',
                style: TextStyle(fontSize: 11, color: Color(0xFF929BAD)),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 78,
                height: 34,
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    suffixText: 's',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF2A313E)),
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFF5B8CFF)),
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                  ),
                  onChanged: (text) {
                    final seconds = int.tryParse(text);
                    if (seconds != null && seconds >= 5 && seconds <= 120) {
                      _setValue(seconds);
                    }
                  },
                  onSubmitted: (text) {
                    final seconds = int.tryParse(text);
                    if (seconds == null || seconds < 5 || seconds > 120) {
                      _controller.text = '$_value';
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final seconds in const [15, 30, 60, 90, 120])
                _quickChip(seconds),
            ],
          ),
        ],
      ),
    );
  }
}
