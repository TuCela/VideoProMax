// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 代码绘制的简约壁纸。
///
/// 设计约束（优先级最高的是可读性）：
/// 1. 所有图案都是低对比、无文字的柔和渐变/细线，不出现高频噪点；
/// 2. 壁纸层整体按 [WallpaperState.intensity] 做半透明衰减，最终叠加在
///    `#0B0E14` 底色上，等效亮度上限约 12%，卡片与播放器仍然是完全不透明
///    深色底板，正文永远落在高对比背景上；
/// 3. 只在窗口留白、间距和页面底板处可见，不参与任何交互。

/// 一套壁纸风格的绘制函数。
typedef WallpaperPaint = void Function(Canvas canvas, Size size, bool isDay);

/// 壁纸风格元数据。
@immutable
class WallpaperStyle {
  const WallpaperStyle({
    required this.id,
    required this.name,
    required this.desc,
    required this.paint,
    this.dayNight = false,
  });

  final String id;
  final String name;
  final String desc;
  final WallpaperPaint paint;

  /// 是否有「日间 / 夜间」两套配色。
  final bool dayNight;
}

Color _c(int value) => Color(value);
Color _a(Color color, double alpha) => color.withValues(alpha: alpha);

// ---------------------------------------------------------------- 绘制工具

void _fillLinear(
  Canvas canvas,
  Size size,
  List<Color> colors, {
  Alignment begin = Alignment.topLeft,
  Alignment end = Alignment.bottomRight,
}) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: begin,
        end: end,
        colors: colors,
      ).createShader(rect),
  );
}

/// 柔光：以 [center]（-1~1 的归一化坐标）为中心画一团径向光晕。
void _glow(
  Canvas canvas,
  Size size,
  Alignment center,
  double radiusX,
  double radiusY,
  Color color, {
  double coreAlpha = 1,
}) {
  final cx = (center.x + 1) / 2 * size.width;
  final cy = (center.y + 1) / 2 * size.height;
  final rect = Rect.fromCenter(
    center: Offset(cx, cy),
    width: size.width * radiusX * 2,
    height: size.height * radiusY * 2,
  );
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: color.a * coreAlpha),
          color.withValues(alpha: color.a * coreAlpha * 0.55),
          color.withValues(alpha: 0),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(rect),
  );
}

/// 一条被模糊过的弯曲光带（极光、雾带共用）。
void _ribbon(
  Canvas canvas,
  Size size,
  List<Color> colors, {
  required double baseY,
  required double amplitude,
  required double waves,
  required double phase,
  required double thickness,
  double blur = 26,
  double alpha = 1,
}) {
  final path = Path();
  const steps = 64;
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    final y = baseY +
        amplitude * math.sin(t * math.pi * 2 * waves + phase) +
        amplitude * 0.35 * math.sin(t * math.pi * 2 * waves * 2.6 + phase * 1.7);
    final x = t * size.width;
    if (i == 0) {
      path.moveTo(x, y - thickness / 2);
    } else {
      path.lineTo(x, y - thickness / 2);
    }
  }
  for (var i = steps; i >= 0; i--) {
    final t = i / steps;
    final y = baseY +
        amplitude * math.sin(t * math.pi * 2 * waves + phase) +
        amplitude * 0.35 * math.sin(t * math.pi * 2 * waves * 2.6 + phase * 1.7);
    path.lineTo(t * size.width, y + thickness / 2);
  }
  path.close();
  final rect = path.getBounds();
  canvas.drawPath(
    path,
    Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur)
      ..color = Colors.white.withValues(alpha: alpha)
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: colors,
      ).createShader(rect),
  );
}

// ---------------------------------------------------------------- 1 石墨

void _paintGraphite(Canvas canvas, Size size, bool isDay) {
  _fillLinear(
    canvas,
    size,
    isDay
        ? [_c(0xFF232E3E), _c(0xFF37475C), _c(0xFF1A222E)]
        : [_c(0xFF0B0F16), _c(0xFF1F2A3B), _c(0xFF0C1017)],
  );
  _glow(
    canvas,
    size,
    const Alignment(-0.85, -0.95),
    0.95,
    0.85,
    _a(_c(0xFF6E9BFF), isDay ? 0.40 : 0.36),
  );
  // 一道很宽的斜向柔光，让「石墨」在低强度下也能看出层次。
  _ribbon(
    canvas,
    size,
    [
      Colors.transparent,
      _a(isDay ? _c(0xFFDCE7F5) : _c(0xFF9DB4D8), isDay ? 0.16 : 0.12),
      Colors.transparent,
    ],
    baseY: size.height * 0.30,
    amplitude: size.height * 0.03,
    waves: 0.55,
    phase: 1.1,
    thickness: size.height * 0.34,
    blur: 70,
  );
  _glow(
    canvas,
    size,
    const Alignment(1.0, 1.0),
    0.7,
    0.65,
    _a(_c(0xFF2BB3A3), isDay ? 0.18 : 0.16),
  );
}

// ---------------------------------------------------------------- 2 晨雾（日夜双版）

void _paintMist(Canvas canvas, Size size, bool isDay) {
  _fillLinear(
    canvas,
    size,
    isDay
        ? [_c(0xFF232E3C), _c(0xFF32404F), _c(0xFF1A222C)]
        : [_c(0xFF070B12), _c(0xFF12202F), _c(0xFF0A1119)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );
  _glow(
    canvas,
    size,
    const Alignment(-0.45, -0.35),
    0.95,
    0.8,
    _a(isDay ? _c(0xFFBFD4E8) : _c(0xFF2E5A86), isDay ? 0.30 : 0.30),
  );
  _glow(
    canvas,
    size,
    const Alignment(0.7, -0.6),
    0.8,
    0.7,
    _a(isDay ? _c(0xFFF0D9BE) : _c(0xFF1E3A5C), isDay ? 0.18 : 0.20),
  );
  _glow(
    canvas,
    size,
    const Alignment(0.1, 0.85),
    1.1,
    0.55,
    _a(isDay ? _c(0xFF9FB4C8) : _c(0xFF17324C), isDay ? 0.16 : 0.14),
  );
}

// ---------------------------------------------------------------- 3 极光

void _paintAurora(Canvas canvas, Size size, bool isDay) {
  _fillLinear(
    canvas,
    size,
    isDay
        ? [_c(0xFF1C2530), _c(0xFF212E3C), _c(0xFF141B25)]
        : [_c(0xFF07090F), _c(0xFF0C1220), _c(0xFF090C12)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  canvas.save();
  canvas.translate(size.width * 0.5, size.height * 0.45);
  canvas.rotate(-0.30);
  canvas.translate(-size.width * 0.5, -size.height * 0.45);

  _ribbon(
    canvas,
    size,
    [
      _a(isDay ? _c(0xFF6FC7B8) : _c(0xFF2BB3A3), 0.0),
      _a(isDay ? _c(0xFF8FD3C6) : _c(0xFF3FD0BF), isDay ? 0.42 : 0.34),
      _a(isDay ? _c(0xFF9CC7E8) : _c(0xFF5B8CFF), isDay ? 0.34 : 0.28),
      _a(isDay ? _c(0xFF8FA0E8) : _c(0xFF7A6BEA), 0.0),
    ],
    baseY: size.height * 0.34,
    amplitude: size.height * 0.06,
    waves: 0.9,
    phase: 0.2,
    thickness: size.height * 0.10,
    blur: 30,
  );
  _ribbon(
    canvas,
    size,
    [
      _a(isDay ? _c(0xFF8FA0E8) : _c(0xFF6C6BE0), 0.0),
      _a(isDay ? _c(0xFFA9B6EC) : _c(0xFF8A7BE8), isDay ? 0.26 : 0.22),
      _a(isDay ? _c(0xFF6FC7B8) : _c(0xFF2BB3A3), 0.0),
    ],
    baseY: size.height * 0.60,
    amplitude: size.height * 0.05,
    waves: 1.4,
    phase: 2.4,
    thickness: size.height * 0.07,
    blur: 34,
  );
  canvas.restore();
  _glow(
    canvas,
    size,
    const Alignment(0.0, 1.15),
    1.0,
    0.5,
    _a(isDay ? _c(0xFF7E93AC) : _c(0xFF1B3A5C), 0.18),
  );
}

// ---------------------------------------------------------------- 4 地平线

void _paintHorizon(Canvas canvas, Size size, bool isDay) {
  _fillLinear(
    canvas,
    size,
    isDay
        ? [_c(0xFF212A36), _c(0xFF2B3746), _c(0xFF151B24)]
        : [_c(0xFF080B11), _c(0xFF101825), _c(0xFF080B12)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  final horizon = size.height * 0.68;
  final vx = size.width * 0.5;
  final lineColor = isDay ? _c(0xFF9FB4CE) : _c(0xFF5B8CFF);

  // 地平线辉光
  _glow(
    canvas,
    size,
    const Alignment(0, 0.36),
    1.0,
    0.20,
    _a(lineColor, isDay ? 0.18 : 0.22),
  );
  // 透视网格（极淡）
  final paint = Paint()
    ..color = _a(lineColor, 0.13)
    ..strokeWidth = 1;
  canvas.save();
  canvas.clipRect(
    Rect.fromLTRB(0, horizon, size.width, size.height),
  );
  for (var i = -9; i <= 9; i++) {
    canvas.drawLine(
      Offset(vx, horizon),
      Offset(vx + i * size.width * 0.22, size.height),
      paint,
    );
  }
  for (var i = 1; i <= 7; i++) {
    final t = i / 7;
    final y = horizon + (size.height - horizon) * math.pow(t, 2.2);
    canvas.drawLine(
      Offset(0, y.toDouble()),
      Offset(size.width, y.toDouble()),
      Paint()..color = _a(lineColor, 0.12 * (1 - t) + 0.03),
    );
  }
  canvas.restore();
  // 地平线本体
  canvas.drawLine(
    Offset(0, horizon),
    Offset(size.width, horizon),
    Paint()
      ..color = _a(lineColor, isDay ? 0.34 : 0.44)
      ..strokeWidth = 1.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
  );
}

// ---------------------------------------------------------------- 5 涟漪

void _paintRipple(Canvas canvas, Size size, bool isDay) {
  _fillLinear(
    canvas,
    size,
    isDay
        ? [_c(0xFF232C39), _c(0xFF2C3847), _c(0xFF161D27)]
        : [_c(0xFF080A10), _c(0xFF111824), _c(0xFF080B11)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  final center = Offset(size.width * 0.78, size.height * 0.72);
  final color = isDay ? _c(0xFF8FA6C4) : _c(0xFF7FA6FF);
  _glow(
    canvas,
    size,
    const Alignment(0.56, 0.44),
    0.55,
    0.5,
    _a(color, isDay ? 0.20 : 0.22),
  );
  final maxRadius = size.longestSide * 0.62;
  for (var i = 0; i < 7; i++) {
    final r = maxRadius * (0.18 + i * 0.13);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _a(color, (0.22 - i * 0.024).clamp(0.03, 0.22)),
    );
  }
}

// ---------------------------------------------------------------- 6 斜纹

void _paintSlate(Canvas canvas, Size size, bool isDay) {
  _fillLinear(
    canvas,
    size,
    isDay
        ? [_c(0xFF222B37), _c(0xFF2A3545), _c(0xFF171E28)]
        : [_c(0xFF080B11), _c(0xFF0F1520), _c(0xFF080A10)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  canvas.save();
  canvas.translate(size.width / 2, size.height / 2);
  canvas.rotate(-math.pi / 4);
  canvas.translate(-size.width / 2, -size.height / 2);
  final span = size.longestSide;
  final tint = isDay ? _c(0xFF8FA6C4) : _c(0xFF5B8CFF);
  // 两条宽斜带
  for (final entry in <({double x, double w, double a})>[
    (x: -0.12, w: 0.34, a: 0.10),
    (x: 0.46, w: 0.20, a: 0.07),
  ]) {
    final rect = Rect.fromLTWH(
      size.width * entry.x,
      -span,
      size.width * entry.w,
      span * 3,
    );
    canvas.drawRect(rect, Paint()..color = _a(tint, entry.a));
  }
  // 细斜线
  for (var i = 0; i < 14; i++) {
    final x = size.width * (-0.2 + i * 0.09);
    canvas.drawLine(
      Offset(x, -span),
      Offset(x, span * 2),
      Paint()
        ..color = _a(tint, 0.035)
        ..strokeWidth = 1,
    );
  }
  canvas.restore();
  _glow(
    canvas,
    size,
    const Alignment(-0.9, 1.0),
    0.8,
    0.6,
    _a(isDay ? _c(0xFFB7C6D8) : _c(0xFF28405E), 0.14),
  );
}

// ---------------------------------------------------------------- 风格清单

/// 6 套可选壁纸（顺序即设置页展示顺序）。
const List<WallpaperStyle> kWallpaperStyles = [
  WallpaperStyle(
    id: 'graphite',
    name: '石墨',
    desc: '深灰纵向渐变，左上冷蓝柔光',
    paint: _paintGraphite,
  ),
  WallpaperStyle(
    id: 'mist',
    name: '晨雾',
    desc: '大面积柔雾光斑，含日间 / 夜间两版',
    paint: _paintMist,
    dayNight: true,
  ),
  WallpaperStyle(
    id: 'aurora',
    name: '极光',
    desc: '两条低饱和斜向光带',
    paint: _paintAurora,
  ),
  WallpaperStyle(
    id: 'horizon',
    name: '地平线',
    desc: '底部冷光线与极淡透视网格',
    paint: _paintHorizon,
  ),
  WallpaperStyle(
    id: 'ripple',
    name: '涟漪',
    desc: '右下角同心细环',
    paint: _paintRipple,
  ),
  WallpaperStyle(
    id: 'slate',
    name: '斜纹',
    desc: '45° 双斜带与细斜线',
    paint: _paintSlate,
  ),
];

WallpaperStyle? wallpaperStyleById(String id) {
  for (final style in kWallpaperStyles) {
    if (style.id == id) return style;
  }
  return null;
}

// ---------------------------------------------------------------- 状态

/// 壁纸状态：风格 id、整体强度、是否跟随时间切换日夜。
@immutable
class WallpaperState {
  const WallpaperState({
    this.styleId = 'graphite',
    this.intensity = 0.40,
    this.auto = true,
    this.manualDay = false,
  });

  final String styleId;

  /// 壁纸可见强度 0~0.7；0 等于关闭。
  final double intensity;

  /// true：按本地时间自动切换（7:00-19:00 日间）。
  final bool auto;
  final bool manualDay;

  WallpaperStyle? get style => wallpaperStyleById(styleId);

  bool get enabled => intensity > 0.001 && style != null;

  /// 实际生效的日/夜；没有双配色的风格固定夜间。
  bool isDayAt(DateTime now) {
    final style = this.style;
    if (style == null || !style.dayNight) return false;
    if (!auto) return manualDay;
    return now.hour >= 7 && now.hour < 19;
  }

  WallpaperState copyWith({
    String? styleId,
    double? intensity,
    bool? auto,
    bool? manualDay,
  }) {
    return WallpaperState(
      styleId: styleId ?? this.styleId,
      intensity: intensity ?? this.intensity,
      auto: auto ?? this.auto,
      manualDay: manualDay ?? this.manualDay,
    );
  }
}

/// 全局壁纸设置（单例 + ValueNotifier，做法与 FontSettings 一致，
/// 避免把壁纸状态层层透传到 3000 行的 HomePage）。
class WallpaperSettings {
  WallpaperSettings._();

  static final WallpaperSettings instance = WallpaperSettings._();

  final ValueNotifier<WallpaperState> state =
      ValueNotifier<WallpaperState>(const WallpaperState());

  bool _envApplied = false;

  /// 支持用环境变量覆盖，便于截图与回归：
  /// `VIDEOHUB_WALLPAPER=aurora VIDEOHUB_INTENSITY=0.3 VIDEOHUB_TONE=day`。
  void applyEnvironmentOverride() {
    if (_envApplied) return;
    _envApplied = true;
    final env = Platform.environment;
    final id = env['VIDEOHUB_WALLPAPER'];
    final tone = env['VIDEOHUB_TONE'];
    final intensity = double.tryParse(env['VIDEOHUB_INTENSITY'] ?? '');
    final current = state.value;
    var next = current;
    if (id != null && id.isNotEmpty) {
      next = next.copyWith(styleId: id == 'none' ? '' : id);
    }
    if (tone == 'day' || tone == 'night') {
      next = next.copyWith(auto: false, manualDay: tone == 'day');
    }
    if (intensity != null) {
      next = next.copyWith(intensity: intensity.clamp(0.0, 0.7));
    }
    state.value = next;
  }

  void update(WallpaperState next) => state.value = next;
}

// ---------------------------------------------------------------- 组件

/// 壁纸绘制层（不含子节点），可在设置页做缩略图。
class WallpaperCanvas extends StatelessWidget {
  const WallpaperCanvas({
    super.key,
    required this.style,
    required this.isDay,
    this.intensity = 1,
  });

  final WallpaperStyle style;
  final bool isDay;
  final double intensity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF0B0E14)),
      child: Opacity(
        opacity: intensity.clamp(0.0, 1.0),
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _WallpaperPainter(style: style, isDay: isDay),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _WallpaperPainter extends CustomPainter {
  const _WallpaperPainter({required this.style, required this.isDay});

  final WallpaperStyle style;
  final bool isDay;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    style.paint(canvas, size, isDay);
  }

  @override
  bool shouldRepaint(_WallpaperPainter old) =>
      old.style.id != style.id || old.isDay != isDay;
}

/// 铺满父级的背景层；[child] 叠在壁纸之上。
class WallpaperBackground extends StatelessWidget {
  const WallpaperBackground({
    super.key,
    required this.state,
    required this.isDay,
    required this.child,
  });

  final WallpaperState state;
  final bool isDay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = state.style;
    if (style == null || state.intensity <= 0.001) {
      return ColoredBox(color: const Color(0xFF0B0E14), child: child);
    }
    // 日间配色本身更亮，同样强度下会被压得过暗，这里做一点补偿。
    final effective = isDay
        ? (state.intensity * 1.25).clamp(0.0, 0.65)
        : state.intensity;
    return Stack(
      fit: StackFit.expand,
      children: [
        WallpaperCanvas(
          style: style,
          isDay: isDay,
          intensity: effective,
        ),
        // 顶部/底部再加一层极淡的压暗，保证标题栏与列表边缘的对比度。
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF000000).withValues(alpha: 0.10),
                  Colors.transparent,
                  const Color(0xFF000000).withValues(alpha: 0.12),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}