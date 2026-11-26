// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter/services.dart';

/// 窗口操作通道。Windows 侧实现见 `windows/runner/flutter_window.cpp`
/// 的 `videohub/window` MethodChannel。
///
/// 抽成公共入口，让顶栏、设置页、播放器全屏等位置共用同一份通道，
/// 不必各自维护一个 MethodChannel 常量。
class WindowChrome {
  WindowChrome._();

  static const MethodChannel _channel = MethodChannel('videohub/window');

  static Future<void> invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } catch (_) {
      // 非 Windows 平台或通道未注册时静默忽略。
    }
  }

  /// 按住拖动窗口（标题栏空白处常用）。
  static void drag() => invoke('drag');

  /// 最大化 / 还原切换。
  static void maximize() => invoke('maximize');

  static void minimize() => invoke('minimize');

  static void close() => invoke('close');
}
