// Copyright (c) 2026 flysky
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 本机偏好设置（弹幕、音量、画面比例）
class AppPrefs {
  bool danmakuOn = true;
  double danmakuOpacity = 0.85;
  double danmakuScale = 1.0;
  double danmakuSpeed = 1.0;
  double danmakuArea = 0.5;
  double volume = 100;
  String fit = 'contain';

  /// 下载画质 id（-1 表示每集都弹窗选择，其它为固定的画质 id）。
  int downloadQualityId = -1;

  /// 下载线程数（1~16）。
  int downloadThreads = 4;

  /// 下载限速（字节/秒），0 表示不限速。
  int downloadSpeedLimit = 0;

  /// 全局字体增量（px）。
  int fontDelta = 0;

  /// 预缓冲目标时长（秒）。
  int bufferSeconds = 60;

  /// 当前视频源平台（bili / youtube / other）。
  String platform = 'bili';

  /// 最后一次从视频下方点击进入的 UP 主 mid（0 表示还没点过）。
  int lastUpMid = 0;

  File? _file;

  Future<void> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}prefs.json');
      _file = file;
      if (!await file.exists()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return;
      danmakuOn = raw['danmakuOn'] as bool? ?? danmakuOn;
      danmakuOpacity =
          (raw['danmakuOpacity'] as num?)?.toDouble() ?? danmakuOpacity;
      danmakuScale = (raw['danmakuScale'] as num?)?.toDouble() ?? danmakuScale;
      danmakuSpeed = (raw['danmakuSpeed'] as num?)?.toDouble() ?? danmakuSpeed;
      danmakuArea = (raw['danmakuArea'] as num?)?.toDouble() ?? danmakuArea;
      volume = (raw['volume'] as num?)?.toDouble() ?? volume;
      fit = raw['fit'] as String? ?? fit;
      downloadQualityId =
          (raw['downloadQualityId'] as num?)?.toInt() ?? downloadQualityId;
      downloadThreads =
          (raw['downloadThreads'] as num?)?.toInt() ?? downloadThreads;
      downloadSpeedLimit =
          (raw['downloadSpeedLimit'] as num?)?.toInt() ?? downloadSpeedLimit;
      fontDelta = (raw['fontDelta'] as num?)?.toInt() ?? fontDelta;
      bufferSeconds =
          (raw['bufferSeconds'] as num?)?.toInt().clamp(5, 120) ??
          bufferSeconds;
      platform = raw['platform'] as String? ?? platform;
      lastUpMid = (raw['lastUpMid'] as num?)?.toInt() ?? lastUpMid;
    } catch (_) {
      // 配置损坏就用默认值
    }
  }

  Future<void> save() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file =
          _file ?? File('${dir.path}${Platform.pathSeparator}prefs.json');
      _file = file;
      await file.writeAsString(
        jsonEncode({
          'danmakuOn': danmakuOn,
          'danmakuOpacity': danmakuOpacity,
          'danmakuScale': danmakuScale,
          'danmakuSpeed': danmakuSpeed,
          'danmakuArea': danmakuArea,
          'volume': volume,
          'fit': fit,
          'downloadQualityId': downloadQualityId,
          'downloadThreads': downloadThreads,
          'downloadSpeedLimit': downloadSpeedLimit,
          'fontDelta': fontDelta,
          'bufferSeconds': bufferSeconds,
          'platform': platform,
          'lastUpMid': lastUpMid,
        }),
      );
    } catch (_) {
      // 保存失败不影响播放
    }
  }
}
