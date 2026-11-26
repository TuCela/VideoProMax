// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter/material.dart';

/// 可阅读区域底板的不透明度设置（单例 + ValueNotifier）。
///
/// 卡片、栏、面板等承载正文的表面统一使用 [color] 作为底板，
/// 与壁纸解耦 —— 换任何壁纸都能保持正文对比度。
/// 用单例避免把设置层层透传到十几个页面。
class SurfaceSettings {
  SurfaceSettings._();

  static final SurfaceSettings instance = SurfaceSettings._();

  static const double minOpacity = 0.40;
  static const double maxOpacity = 1.00;
  static const double defaultOpacity = 0.50;

  final ValueNotifier<double> opacity =
      ValueNotifier<double>(defaultOpacity);

  /// 各可阅读区域复用的深色半透明底板。
  Color get color =>
      const Color(0xFF141820).withValues(alpha: opacity.value);

  void update(double value) =>
      opacity.value = value.clamp(minOpacity, maxOpacity);
}
