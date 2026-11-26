// Copyright (c) 2026 flysky
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter/foundation.dart';

/// 全局字体大小设置。
///
/// 以 14px 为基准，每次调节 ±1px。通过 TextScaler 线性倍率作用到
/// 整个 MaterialApp，实现全局所有文字统一缩放。
class FontSettings {
  FontSettings._();

  static final FontSettings instance = FontSettings._();

  /// 字体增量（像素），范围 -4 ~ +12。
  final ValueNotifier<int> delta = ValueNotifier<int>(0);

  /// 基准字体大小（用于把 px 增量换算成 TextScaler 倍率）。
  static const double baseSize = 14.0;

  /// 当前文字缩放倍率。
  double get scaler => (baseSize + delta.value) / baseSize;

  void increase() {
    if (delta.value < 12) delta.value = delta.value + 1;
  }

  void decrease() {
    if (delta.value > -4) delta.value = delta.value - 1;
  }

  void reset() => delta.value = 0;

  void restore(int value) {
    delta.value = value.clamp(-4, 12);
  }
}
