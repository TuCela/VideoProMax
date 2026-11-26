import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 一条播放历史
class HistoryEntry {
  /// 唯一键：普通视频 v:{bvid}:{cid}，版权内容 ep:{epId}
  final String key;
  final String kind; // video | pgc
  final String platform;
  final String videoId;
  final String bvid;
  final String cid;
  final int? epId;
  final int? seasonId;
  final String title;
  final String partTitle;
  final String cover;
  final int positionSeconds;
  final int durationSeconds;
  final int updatedAt;

  /// 是否来自 B站云端历史（只影响显示与删除行为，不落盘）
  final bool fromCloud;

  const HistoryEntry({
    required this.key,
    required this.kind,
    this.platform = 'bilibili',
    this.videoId = '',
    required this.bvid,
    required this.cid,
    this.epId,
    this.seasonId,
    required this.title,
    required this.partTitle,
    required this.cover,
    required this.positionSeconds,
    required this.durationSeconds,
    required this.updatedAt,
    this.fromCloud = false,
  });

  double get progress {
    if (durationSeconds <= 0) return 0;
    return (positionSeconds / durationSeconds).clamp(0.0, 1.0);
  }

  bool get finished => durationSeconds > 0 && positionSeconds == 0;

  Map<String, dynamic> toJson() => {
    'key': key,
    'kind': kind,
    'platform': platform,
    'videoId': videoId,
    'bvid': bvid,
    'cid': cid,
    'epId': epId,
    'seasonId': seasonId,
    'title': title,
    'partTitle': partTitle,
    'cover': cover,
    'positionSeconds': positionSeconds,
    'durationSeconds': durationSeconds,
    'updatedAt': updatedAt,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    key: json['key'] as String? ?? '',
    kind: json['kind'] as String? ?? 'video',
    platform: json['platform'] as String? ?? 'bilibili',
    videoId: json['videoId'] as String? ?? '',
    bvid: json['bvid'] as String? ?? '',
    cid: json['cid'] as String? ?? '',
    epId: (json['epId'] as num?)?.toInt(),
    seasonId: (json['seasonId'] as num?)?.toInt(),
    title: json['title'] as String? ?? '',
    partTitle: json['partTitle'] as String? ?? '',
    cover: json['cover'] as String? ?? '',
    positionSeconds: (json['positionSeconds'] as num?)?.toInt() ?? 0,
    durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
    updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
  );
}

/// 播放历史：本地 JSON，最多保留 100 条
class HistoryStore {
  final List<HistoryEntry> entries = [];

  File? _file;
  bool _loaded = false;

  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}history.json');
      _file = file;
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is List) {
          for (final item in raw) {
            if (item is Map) {
              entries.add(HistoryEntry.fromJson(item.cast<String, dynamic>()));
            }
          }
        }
      }
      entries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      // 历史损坏就当空
    }
    _loaded = true;
  }

  HistoryEntry? find(String key) {
    for (final entry in entries) {
      if (entry.key == key) return entry;
    }
    return null;
  }

  Future<void> upsert(HistoryEntry entry) async {
    entries.removeWhere((item) => item.key == entry.key);
    entries.insert(0, entry);
    if (entries.length > 100) entries.removeRange(100, entries.length);
    await _persist();
  }

  Future<void> remove(String key) async {
    entries.removeWhere((item) => item.key == key);
    await _persist();
  }

  Future<void> clear() async {
    entries.clear();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file =
          _file ?? File('${dir.path}${Platform.pathSeparator}history.json');
      _file = file;
      await file.writeAsString(
        jsonEncode(entries.map((entry) => entry.toJson()).toList()),
      );
    } catch (_) {
      // 写盘失败不影响播放
    }
  }
}
