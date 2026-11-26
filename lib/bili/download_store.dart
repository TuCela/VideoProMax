// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 下载状态（与 download_service.dart 的 DownloadStatus 对应，独立定义
/// 避免持久化层依赖服务层）。
enum DlStatus { pending, downloading, merging, paused, done, failed, canceled }

DlStatus dlStatusFromString(String s) {
  switch (s) {
    case 'downloading':
      return DlStatus.downloading;
    case 'merging':
      return DlStatus.merging;
    case 'paused':
      return DlStatus.paused;
    case 'done':
      return DlStatus.done;
    case 'failed':
      return DlStatus.failed;
    case 'canceled':
      return DlStatus.canceled;
    default:
      return DlStatus.pending;
  }
}

String dlStatusToString(DlStatus s) => s.name;

/// 一条下载记录（持久化 + UI 展示）。
class DownloadRecord {
  DownloadRecord({
    required this.key,
    required this.bvid,
    required this.cid,
    this.platform = 'bilibili',
    this.videoId = '',
    required this.title,
    required this.qualityId,
    required this.qualityLabel,
    this.epId,
    this.cover = '',
    this.status = DlStatus.pending,
    this.progress = 0.0,
    this.message = '',
    this.outputPath = '',
    required this.createdAt,
    this.updatedAt = 0,
  });

  /// 唯一键：ep:{epId} 或 v:{bvid}:{cid}
  final String key;
  final String platform;
  final String videoId;
  final String bvid;
  final String cid;
  final int? epId;
  final String title;
  final String cover;
  final int qualityId;
  final String qualityLabel;
  DlStatus status;
  double progress;

  /// 实时下载速率（字节/秒），仅下载阶段有效。
  double speed = 0.0;

  /// 已下载字节 / 总字节（两个流合计），用于显示大小与剩余时间。
  int downloadedBytes = 0;
  int totalBytes = 0;

  /// 预计剩余秒数，-1 表示未知。
  int etaSeconds = -1;
  String message;
  String outputPath;
  final int createdAt;
  int updatedAt;

  /// 人类可读的速率文本。
  String get speedText {
    if (speed <= 0) return '';
    if (speed >= 1024 * 1024) {
      return '${(speed / 1024 / 1024).toStringAsFixed(1)} MB/s';
    }
    if (speed >= 1024) return '${(speed / 1024).toStringAsFixed(0)} KB/s';
    return '${speed.toStringAsFixed(0)} B/s';
  }

  /// 人类可读的字节数。
  static String formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  String get sizeText =>
      '${formatBytes(downloadedBytes)}/${formatBytes(totalBytes)}';

  /// 人类可读的剩余时间。
  String get etaText {
    if (etaSeconds < 0 || speed <= 0) return '';
    final s = etaSeconds;
    if (s < 60) return '剩余 ${s}s';
    if (s < 3600) return '剩余 ${s ~/ 60}分${s % 60}s';
    return '剩余 ${s ~/ 3600}时${(s % 3600) ~/ 60}分';
  }

  bool get isActive =>
      status == DlStatus.pending ||
      status == DlStatus.downloading ||
      status == DlStatus.merging;
  bool get isPaused => status == DlStatus.paused;
  bool get isDone => status == DlStatus.done;
  bool get isFailed => status == DlStatus.failed || status == DlStatus.canceled;

  Map<String, dynamic> toJson() => {
    'key': key,
    'platform': platform,
    'videoId': videoId,
    'bvid': bvid,
    'cid': cid,
    'epId': epId,
    'title': title,
    'cover': cover,
    'qualityId': qualityId,
    'qualityLabel': qualityLabel,
    'status': dlStatusToString(status),
    'progress': progress,
    'message': message,
    'outputPath': outputPath,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory DownloadRecord.fromJson(Map<String, dynamic> json) => DownloadRecord(
    key: json['key'] as String? ?? '',
    platform: json['platform'] as String? ?? 'bilibili',
    videoId: json['videoId'] as String? ?? '',
    bvid: json['bvid'] as String? ?? '',
    cid: json['cid'] as String? ?? '',
    epId: (json['epId'] as num?)?.toInt(),
    title: json['title'] as String? ?? '',
    cover: json['cover'] as String? ?? '',
    qualityId: (json['qualityId'] as num?)?.toInt() ?? 0,
    qualityLabel: json['qualityLabel'] as String? ?? '',
    status: dlStatusFromString(json['status'] as String? ?? ''),
    progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    message: json['message'] as String? ?? '',
    outputPath: json['outputPath'] as String? ?? '',
    createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
    updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
  );
}

/// 下载记录存储：本地 JSON，重启后保留。
/// revision 用于驱动下载页 UI 刷新。
class DownloadStore {
  final List<DownloadRecord> records = [];

  /// 每次变更自增，UI 监听它刷新。
  int _revision = 0;
  int get revision => _revision;
  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void _notify() {
    _revision++;
    for (final l in List<void Function()>.from(_listeners)) {
      l();
    }
  }

  File? _file;
  bool _loaded = false;
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}downloads.json');
      _file = file;
      if (await file.exists()) {
        final raw = jsonDecode(await file.readAsString());
        if (raw is List) {
          for (final item in raw) {
            if (item is Map) {
              records.add(
                DownloadRecord.fromJson(item.cast<String, dynamic>()),
              );
            }
          }
        }
      }
      // 上次运行时未完成的任务（进程被关 → 中断），标记为失败。
      // 暂停状态的任务保留为暂停，用户点「继续」可从断点续传。
      var changed = false;
      for (final r in records) {
        if (r.isActive) {
          r.status = DlStatus.failed;
          r.message = '软件关闭导致中断，可重试';
          changed = true;
        } else if (r.isPaused) {
          r.message = '已暂停（可继续下载）';
          changed = true;
        }
      }
      records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (changed) await _persist();
    } catch (_) {
      // 记录损坏就当空
    }
    _loaded = true;
    _notify();
  }

  DownloadRecord? find(String key) {
    for (final r in records) {
      if (r.key == key) return r;
    }
    return null;
  }

  Future<DownloadRecord> upsert(DownloadRecord record) async {
    record.updatedAt = DateTime.now().millisecondsSinceEpoch;
    final idx = records.indexWhere((r) => r.key == record.key);
    if (idx >= 0) {
      records[idx] = record;
    } else {
      records.insert(0, record);
    }
    _notify();
    await _persist();
    return record;
  }

  Future<void> update(DownloadRecord record) async {
    record.updatedAt = DateTime.now().millisecondsSinceEpoch;
    _notify();
    await _persist();
  }

  /// 进度高频更新：只广播刷新 UI，不写盘。
  void touch() => _notify();

  Future<void> remove(String key) async {
    records.removeWhere((r) => r.key == key);
    _notify();
    await _persist();
  }

  Future<void> clear() async {
    records.clear();
    _notify();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file =
          _file ?? File('${dir.path}${Platform.pathSeparator}downloads.json');
      _file = file;
      await file.writeAsString(
        jsonEncode(records.map((r) => r.toJson()).toList()),
      );
    } catch (_) {
      // 写盘失败不影响下载
    }
  }
}
