// VideoHub 八款代码壁纸包
//
// 接入方式：把本文件放入 lib/ui/，然后在现有 wallpaper.dart 中：
// 1. import 'videohub_wallpaper_pack.dart';
// 2. 将 kVideoHubWallpaperSpecs 映射为现有 WallpaperStyle：
//
// final extraStyles = [
//   for (final spec in kVideoHubWallpaperSpecs)
//     WallpaperStyle(
//       id: spec.id,
//       name: spec.name,
//       desc: spec.desc,
//       paint: spec.paint,
//     ),
// ];
//
// 3. 将 extraStyles 追加到 kWallpaperStyles 即可。
//
// 所有图案均由 Canvas 代码绘制，不依赖图片、字体、网络或第三方包。

import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef VideoHubWallpaperPaint = void Function(
  Canvas canvas,
  Size size,
  bool isDay,
);

class VideoHubWallpaperSpec {
  const VideoHubWallpaperSpec({
    required this.id,
    required this.name,
    required this.desc,
    required this.paint,
    required this.recommendedIntensity,
  });

  final String id;
  final String name;
  final String desc;
  final VideoHubWallpaperPaint paint;
  final double recommendedIntensity;
}

const List<VideoHubWallpaperSpec> kVideoHubWallpaperSpecs = [
  VideoHubWallpaperSpec(
    id: 'cyberpunk',
    name: '赛博朋克',
    desc: '霓虹城市、透视网格与冷紫青光晕',
    paint: paintVideoHubCyberpunk,
    recommendedIntensity: 0.46,
  ),
  VideoHubWallpaperSpec(
    id: 'ink',
    name: '水墨国风',
    desc: '远山、墨雾、朱砂与竹叶剪影',
    paint: paintVideoHubInk,
    recommendedIntensity: 0.50,
  ),
  VideoHubWallpaperSpec(
    id: 'brush',
    name: '插画笔刷',
    desc: '暖色笔触、干扫线条与留白',
    paint: paintVideoHubBrush,
    recommendedIntensity: 0.42,
  ),
  VideoHubWallpaperSpec(
    id: 'minimal',
    name: '极简',
    desc: '克制几何、细线和大面积负空间',
    paint: paintVideoHubMinimal,
    recommendedIntensity: 0.34,
  ),
  VideoHubWallpaperSpec(
    id: 'bauhaus',
    name: '包豪斯',
    desc: '三原色几何构成与严格网格',
    paint: paintVideoHubBauhaus,
    recommendedIntensity: 0.40,
  ),
  VideoHubWallpaperSpec(
    id: 'vaporwave',
    name: '蒸气波',
    desc: '复古落日、网格地面与棕榈剪影',
    paint: paintVideoHubVaporwave,
    recommendedIntensity: 0.46,
  ),
  VideoHubWallpaperSpec(
    id: 'lowpoly',
    name: '低多边形',
    desc: '深色三角切面与冷色晶石质感',
    paint: paintVideoHubLowPoly,
    recommendedIntensity: 0.44,
  ),
  VideoHubWallpaperSpec(
    id: 'random',
    name: '随机',
    desc: '固定种子生成的抽象随机构成',
    paint: paintVideoHubRandom,
    recommendedIntensity: 0.40,
  ),
];

Color _vhwAlpha(Color color, double alpha) =>
    color.withValues(alpha: alpha.clamp(0.0, 1.0));

void _vhwFill(
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

void _vhwGlow(
  Canvas canvas,
  Size size, {
  required Offset center,
  required double radius,
  required Color color,
  double alpha = 1,
}) {
  final rect = Rect.fromCircle(center: center, radius: radius);
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = RadialGradient(
        colors: [
          _vhwAlpha(color, color.a * alpha),
          _vhwAlpha(color, color.a * alpha * 0.42),
          _vhwAlpha(color, 0),
        ],
        stops: const [0, 0.42, 1],
      ).createShader(rect),
  );
}

void _vhwLine(
  Canvas canvas,
  Offset a,
  Offset b,
  Color color,
  double width, {
  double alpha = 1,
}) {
  canvas.drawLine(
    a,
    b,
    Paint()
      ..color = _vhwAlpha(color, alpha)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
}

void _vhwCircle(
  Canvas canvas,
  Offset center,
  double radius,
  Color color, {
  double alpha = 1,
  bool fill = true,
  double strokeWidth = 1,
}) {
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = _vhwAlpha(color, alpha)
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = strokeWidth,
  );
}

void _vhwVignette(Canvas canvas, Size size, {double strength = 0.52}) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.78,
        colors: [
          Colors.transparent,
          _vhwAlpha(Colors.black, strength * 0.28),
          _vhwAlpha(Colors.black, strength),
        ],
        stops: const [0, 0.58, 1],
      ).createShader(rect),
  );
}

void _vhwPaintMountain(
  Canvas canvas,
  Size size,
  double baseY,
  double amplitude,
  Color color,
  double alpha, {
  double blur = 0,
  double phase = 0,
}) {
  final path = Path();
  const steps = 42;
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    final x = t * size.width;
    final ridge =
        baseY -
        amplitude *
            (0.38 + 0.62 * math.sin(t * math.pi * 3.1 + phase).abs()) *
            (0.72 + 0.28 * math.sin(t * math.pi * 7.0 + phase));
    if (i == 0) {
      path.moveTo(x, ridge);
    } else {
      path.lineTo(x, ridge);
    }
  }
  path.lineTo(size.width, size.height);
  path.lineTo(0, size.height);
  path.close();
  canvas.drawPath(
    path,
    Paint()
      ..color = _vhwAlpha(color, alpha)
      ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null,
  );
}

// ------------------------------------------------------------------ 赛博朋克

void paintVideoHubCyberpunk(Canvas canvas, Size size, bool isDay) {
  _vhwFill(canvas, size, const [
    Color(0xFF05060B),
    Color(0xFF0A1020),
    Color(0xFF170A1D),
  ]);

  _vhwGlow(
    canvas,
    size,
    center: Offset(size.width * 0.16, size.height * 0.22),
    radius: size.shortestSide * 0.52,
    color: const Color(0xFF00D9FF),
    alpha: 0.22,
  );
  _vhwGlow(
    canvas,
    size,
    center: Offset(size.width * 0.84, size.height * 0.68),
    radius: size.shortestSide * 0.58,
    color: const Color(0xFFFF2D95),
    alpha: 0.24,
  );

  final random = math.Random(2077);
  const cyan = Color(0xFF41E8FF);
  const magenta = Color(0xFFFF3FA4);
  final horizon = size.height * 0.64;

  // 城市天际线：只占下半部，中央保持低亮，避免和正文争夺注意力。
  var x = -20.0;
  while (x < size.width) {
    final width = 26 + random.nextDouble() * 58;
    final height = size.height * (0.10 + random.nextDouble() * 0.26);
    final top = horizon - height;
    final rect = Rect.fromLTWH(x, top, width, height);
    canvas.drawRect(
      rect,
      Paint()
        ..color = _vhwAlpha(const Color(0xFF080B14), 0.92)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = _vhwAlpha(random.nextBool() ? cyan : magenta, 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final cols = math.max(2, (width / 12).floor());
    final rows = math.max(3, (height / 15).floor());
    for (var row = 1; row < rows; row++) {
      for (var col = 1; col < cols; col++) {
        if (random.nextDouble() > 0.58) continue;
        final windowColor = random.nextBool() ? cyan : magenta;
        canvas.drawRect(
          Rect.fromLTWH(
            x + col * width / cols,
            top + row * height / rows,
            2.4,
            3.2,
          ),
          Paint()
            ..color = _vhwAlpha(windowColor, 0.20 + random.nextDouble() * 0.35),
        );
      }
    }
    x += width + 5 + random.nextDouble() * 8;
  }

  // 透视地面网格。
  for (var i = -7; i <= 7; i++) {
    final bottomX = size.width * 0.5 + i * size.width * 0.11;
    _vhwLine(
      canvas,
      Offset(size.width * 0.5 + i * 8, horizon),
      Offset(bottomX, size.height),
      i.isEven ? cyan : magenta,
      1,
      alpha: 0.14,
    );
  }
  for (var i = 1; i <= 7; i++) {
    final t = i / 7;
    final y = horizon + (size.height - horizon) * t * t;
    _vhwLine(
      canvas,
      Offset(0, y),
      Offset(size.width, y),
      cyan,
      1,
      alpha: 0.08 + t * 0.08,
    );
  }

  // 两条斜向霓虹线。
  _vhwLine(
    canvas,
    Offset(size.width * 0.04, size.height * 0.44),
    Offset(size.width * 0.42, size.height * 0.10),
    cyan,
    2,
    alpha: 0.32,
  );
  _vhwLine(
    canvas,
    Offset(size.width * 0.62, size.height * 0.94),
    Offset(size.width * 0.98, size.height * 0.52),
    magenta,
    2,
    alpha: 0.30,
  );

  _vhwVignette(canvas, size, strength: 0.60);
}

// ------------------------------------------------------------------ 水墨国风

void paintVideoHubInk(Canvas canvas, Size size, bool isDay) {
  _vhwFill(
    canvas,
    size,
    isDay
        ? const [Color(0xFF1A1D1C), Color(0xFF2A2C28), Color(0xFF141718)]
        : const [Color(0xFF090C0E), Color(0xFF171B1C), Color(0xFF090C0E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  final sun = Offset(size.width * 0.74, size.height * 0.27);
  _vhwCircle(
    canvas,
    sun,
    size.shortestSide * 0.085,
    const Color(0xFFB6463B),
    alpha: isDay ? 0.54 : 0.42,
  );

  _vhwPaintMountain(
    canvas,
    size,
    size.height * 0.58,
    size.height * 0.28,
    const Color(0xFF687274),
    0.18,
    blur: 18,
    phase: 0.7,
  );
  _vhwPaintMountain(
    canvas,
    size,
    size.height * 0.70,
    size.height * 0.25,
    const Color(0xFF3D494B),
    0.42,
    blur: 7,
    phase: 2.1,
  );
  _vhwPaintMountain(
    canvas,
    size,
    size.height * 0.83,
    size.height * 0.20,
    const Color(0xFF182124),
    0.82,
    phase: 4.4,
  );

  // 雾带。
  for (var i = 0; i < 3; i++) {
    final y = size.height * (0.54 + i * 0.09);
    canvas.drawRect(
      Rect.fromLTWH(0, y - 12, size.width, 28),
      Paint()
        ..color = _vhwAlpha(const Color(0xFFB7C2BD), 0.035)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  // 竹叶剪影：少量、低对比，集中在两侧。
  final bamboo = Paint()
    ..color = _vhwAlpha(const Color(0xFF0A1011), 0.72)
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  for (var stem = 0; stem < 4; stem++) {
    final baseX = size.width * (0.05 + stem * 0.035);
    final topX = baseX + size.width * 0.03;
    canvas.drawLine(
      Offset(baseX, size.height),
      Offset(topX, size.height * 0.18),
      bamboo,
    );
    for (var leaf = 0; leaf < 5; leaf++) {
      final y = size.height * (0.30 + leaf * 0.11);
      final x = baseX + (topX - baseX) * (1 - (y / size.height));
      final dir = leaf.isEven ? 1 : -1;
      final leafPath = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(
          x + dir * size.width * 0.045,
          y - size.height * 0.035,
          x + dir * size.width * 0.075,
          y - size.height * 0.012,
        )
        ..quadraticBezierTo(
          x + dir * size.width * 0.04,
          y + size.height * 0.006,
          x,
          y,
        );
      canvas.drawPath(leafPath, bamboo);
    }
  }

  // 朱砂印章意象（无文字，避免壁纸出现可读内容）。
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.88,
        size.height * 0.82,
        size.shortestSide * 0.038,
        size.shortestSide * 0.038,
      ),
      const Radius.circular(2),
    ),
    Paint()..color = _vhwAlpha(const Color(0xFFA53B32), 0.48),
  );

  _vhwVignette(canvas, size, strength: 0.46);
}

// ------------------------------------------------------------------ 插画笔刷

void paintVideoHubBrush(Canvas canvas, Size size, bool isDay) {
  _vhwFill(canvas, size, const [
    Color(0xFF141014),
    Color(0xFF21171A),
    Color(0xFF10141A),
  ]);

  final strokes = <({Color color, double alpha, double width, double phase})>[
    (color: const Color(0xFFC9773E), alpha: 0.30, width: 0.20, phase: 0.2),
    (color: const Color(0xFF3F7E83), alpha: 0.28, width: 0.13, phase: 1.8),
    (color: const Color(0xFF873D58), alpha: 0.30, width: 0.17, phase: 3.2),
  ];

  for (final stroke in strokes) {
    final path = Path();
    const steps = 56;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = -size.width * 0.12 + t * size.width * 1.24;
      final y =
          size.height * (0.25 + stroke.phase * 0.12) +
          math.sin(t * math.pi * 2.2 + stroke.phase) *
              size.height *
              stroke.width *
              0.42;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _vhwAlpha(stroke.color, stroke.alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          size.shortestSide * 0.012,
        ),
    );

    // 干扫细线。
    for (var i = 0; i < 7; i++) {
      final offset = (i - 3) * size.shortestSide * 0.012;
      canvas.drawPath(
        path,
        Paint()
          ..color = _vhwAlpha(stroke.color, 0.08 + i * 0.008)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
      if (offset != 0) {
        canvas.save();
        canvas.translate(0, offset);
        canvas.drawPath(
          path,
          Paint()
            ..color = _vhwAlpha(stroke.color, 0.06)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        canvas.restore();
      }
    }
  }

  // 颜料点。
  final random = math.Random(brushSeed);
  for (var i = 0; i < 26; i++) {
    final center = Offset(
      random.nextDouble() * size.width,
      random.nextDouble() * size.height,
    );
    final radius = 2 + random.nextDouble() * size.shortestSide * 0.018;
    _vhwCircle(
      canvas,
      center,
      radius,
      i.isEven ? const Color(0xFFD59A55) : const Color(0xFF5B9391),
      alpha: 0.08 + random.nextDouble() * 0.16,
    );
  }

  _vhwVignette(canvas, size, strength: 0.42);
}

// ------------------------------------------------------------------ 极简

void paintVideoHubMinimal(Canvas canvas, Size size, bool isDay) {
  _vhwFill(
    canvas,
    size,
    const [Color(0xFF0E1117), Color(0xFF111722), Color(0xFF0E1117)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final center = Offset(size.width * 0.72, size.height * 0.30);
  _vhwCircle(
    canvas,
    center,
    size.shortestSide * 0.17,
    const Color(0xFF5B8CFF),
    alpha: 0.20,
    fill: false,
    strokeWidth: 1.4,
  );
  _vhwCircle(
    canvas,
    Offset(size.width * 0.24, size.height * 0.72),
    size.shortestSide * 0.032,
    const Color(0xFF69DB7C),
    alpha: 0.34,
  );
  _vhwLine(
    canvas,
    Offset(size.width * 0.16, size.height * 0.58),
    Offset(size.width * 0.48, size.height * 0.58),
    const Color(0xFF929BAD),
    1,
    alpha: 0.24,
  );
  _vhwLine(
    canvas,
    Offset(size.width * 0.16, size.height * 0.58),
    Offset(size.width * 0.16, size.height * 0.74),
    const Color(0xFF929BAD),
    1,
    alpha: 0.18,
  );

  _vhwVignette(canvas, size, strength: 0.30);
}

// ------------------------------------------------------------------ 包豪斯

void paintVideoHubBauhaus(Canvas canvas, Size size, bool isDay) {
  _vhwFill(canvas, size, const [
    Color(0xFF111318),
    Color(0xFF171A20),
    Color(0xFF0E1117),
  ]);

  const red = Color(0xFFE25555);
  const yellow = Color(0xFFE7C75B);
  const blue = Color(0xFF4D78D8);
  final unit = size.shortestSide;

  // 左上圆。
  _vhwCircle(
    canvas,
    Offset(size.width * 0.18, size.height * 0.24),
    unit * 0.12,
    blue,
    alpha: 0.42,
  );

  // 右上矩形。
  canvas.drawRect(
    Rect.fromLTWH(
      size.width * 0.70,
      size.height * 0.12,
      size.width * 0.16,
      size.height * 0.20,
    ),
    Paint()..color = _vhwAlpha(red, 0.38),
  );

  // 左下三角。
  final triangle = Path()
    ..moveTo(size.width * 0.10, size.height * 0.82)
    ..lineTo(size.width * 0.30, size.height * 0.58)
    ..lineTo(size.width * 0.34, size.height * 0.84)
    ..close();
  canvas.drawPath(triangle, Paint()..color = _vhwAlpha(yellow, 0.38));

  // 右下半圆。
  final semicircle = Path()
    ..moveTo(size.width * 0.76, size.height * 0.70)
    ..arcTo(
      Rect.fromCircle(
        center: Offset(size.width * 0.76, size.height * 0.70),
        radius: unit * 0.11,
      ),
      math.pi,
      math.pi,
      false,
    )
    ..close();
  canvas.drawPath(semicircle, Paint()..color = _vhwAlpha(blue, 0.32));

  // 构成线。
  _vhwLine(
    canvas,
    Offset(size.width * 0.38, size.height * 0.12),
    Offset(size.width * 0.38, size.height * 0.88),
    const Color(0xFFEDF0F7),
    1,
    alpha: 0.14,
  );
  _vhwLine(
    canvas,
    Offset(size.width * 0.08, size.height * 0.48),
    Offset(size.width * 0.92, size.height * 0.48),
    const Color(0xFFEDF0F7),
    1,
    alpha: 0.12,
  );
  _vhwLine(
    canvas,
    Offset(size.width * 0.52, size.height * 0.16),
    Offset(size.width * 0.68, size.height * 0.40),
    red,
    3,
    alpha: 0.26,
  );

  _vhwVignette(canvas, size, strength: 0.42);
}

// ------------------------------------------------------------------ 蒸气波

void paintVideoHubVaporwave(Canvas canvas, Size size, bool isDay) {
  _vhwFill(
    canvas,
    size,
    const [Color(0xFF140C2B), Color(0xFF321447), Color(0xFF0A1020)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  final random = math.Random(vaporSeed);
  for (var i = 0; i < 70; i++) {
    _vhwCircle(
      canvas,
      Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height * 0.58,
      ),
      0.6 + random.nextDouble() * 1.2,
      const Color(0xFFE9D7FF),
      alpha: 0.12 + random.nextDouble() * 0.20,
    );
  }

  final sunCenter = Offset(size.width * 0.50, size.height * 0.34);
  final sunRadius = size.shortestSide * 0.16;
  final sunRect = Rect.fromCircle(center: sunCenter, radius: sunRadius);
  canvas.drawCircle(
    sunCenter,
    sunRadius,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _vhwAlpha(const Color(0xFFFFD36B), 0.72),
          _vhwAlpha(const Color(0xFFFF6FAE), 0.56),
        ],
      ).createShader(sunRect),
  );

  // 落日横纹。
  for (var i = 0; i < 7; i++) {
    final y = sunCenter.dy + sunRadius * (0.05 + i * 0.12);
    final half = math.sqrt(
      math.max(
        0,
        sunRadius * sunRadius - (y - sunCenter.dy) * (y - sunCenter.dy),
      ),
    );
    canvas.drawRect(
      Rect.fromLTWH(sunCenter.dx - half, y, half * 2, 2 + i * 0.7),
      Paint()..color = _vhwAlpha(const Color(0xFF26103D), 0.82),
    );
  }

  final horizon = size.height * 0.62;
  for (var i = -8; i <= 8; i++) {
    _vhwLine(
      canvas,
      Offset(size.width * 0.5 + i * 6, horizon),
      Offset(size.width * 0.5 + i * size.width * 0.13, size.height),
      const Color(0xFF59E1FF),
      1,
      alpha: 0.16,
    );
  }
  for (var i = 1; i <= 9; i++) {
    final t = i / 9;
    final y = horizon + (size.height - horizon) * t * t;
    _vhwLine(
      canvas,
      Offset(0, y),
      Offset(size.width, y),
      const Color(0xFFFF5DBB),
      1,
      alpha: 0.12 + t * 0.10,
    );
  }

  // 两侧棕榈剪影。
  final palm = Paint()..color = _vhwAlpha(Colors.black, 0.58);
  for (final side in [-1, 1]) {
    final baseX = size.width * (side < 0 ? 0.10 : 0.90);
    final topX = baseX + side * size.width * 0.035;
    final topY = size.height * 0.46;
    canvas.drawLine(
      Offset(baseX, horizon),
      Offset(topX, topY),
      palm..strokeWidth = 5,
    );
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi * 0.92 + i * math.pi * 0.184;
      final length = size.shortestSide * 0.13;
      final end = Offset(
        topX + math.cos(angle) * length,
        topY + math.sin(angle) * length * 0.55,
      );
      canvas.drawLine(Offset(topX, topY), end, palm..strokeWidth = 3);
    }
  }

  _vhwVignette(canvas, size, strength: 0.52);
}

// ------------------------------------------------------------------ 低多边形

void paintVideoHubLowPoly(Canvas canvas, Size size, bool isDay) {
  _vhwFill(canvas, size, const [
    Color(0xFF080D1A),
    Color(0xFF11182B),
    Color(0xFF090D18),
  ]);

  _vhwGlow(
    canvas,
    size,
    center: Offset(size.width * 0.66, size.height * 0.34),
    radius: size.shortestSide * 0.58,
    color: const Color(0xFF5468D8),
    alpha: 0.16,
  );

  final random = math.Random(lowPolySeed);
  const palette = [
    Color(0xFF1D2A4D),
    Color(0xFF27375E),
    Color(0xFF31406A),
    Color(0xFF23324D),
    Color(0xFF3A3159),
    Color(0xFF1B3342),
  ];
  final cell = size.shortestSide / 5.2;
  final cols = (size.width / cell).ceil() + 2;
  final rows = (size.height / cell).ceil() + 2;
  final points = <List<Offset>>[];
  for (var row = 0; row < rows; row++) {
    final list = <Offset>[];
    for (var col = 0; col < cols; col++) {
      list.add(
        Offset(
          (col - 1) * cell + (random.nextDouble() - 0.5) * cell * 0.72,
          (row - 1) * cell + (random.nextDouble() - 0.5) * cell * 0.72,
        ),
      );
    }
    points.add(list);
  }

  for (var row = 0; row < rows - 1; row++) {
    for (var col = 0; col < cols - 1; col++) {
      final a = points[row][col];
      final b = points[row][col + 1];
      final c = points[row + 1][col];
      final d = points[row + 1][col + 1];
      final triangles = [
        [a, b, c],
        [b, d, c],
      ];
      for (final triangle in triangles) {
        final path = Path()
          ..moveTo(triangle[0].dx, triangle[0].dy)
          ..lineTo(triangle[1].dx, triangle[1].dy)
          ..lineTo(triangle[2].dx, triangle[2].dy)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = _vhwAlpha(
              palette[random.nextInt(palette.length)],
              0.30 + random.nextDouble() * 0.26,
            )
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = _vhwAlpha(const Color(0xFF0A0F1B), 0.18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7,
        );
      }
    }
  }

  _vhwVignette(canvas, size, strength: 0.50);
}

// ------------------------------------------------------------------ 随机

const int brushSeed = 20261126;
const int vaporSeed = 1984;
const int lowPolySeed = 731;
const int randomSeed = 20261126;

void paintVideoHubRandom(Canvas canvas, Size size, bool isDay) {
  _vhwFill(canvas, size, const [
    Color(0xFF0B0F18),
    Color(0xFF151322),
    Color(0xFF0A1018),
  ]);

  final random = math.Random(randomSeed);
  const palette = [
    Color(0xFF5B8CFF),
    Color(0xFF9B6CFF),
    Color(0xFF41C7C7),
    Color(0xFFE06B8D),
    Color(0xFFE4C15D),
    Color(0xFF78B89A),
  ];

  for (var i = 0; i < 22; i++) {
    final color = palette[random.nextInt(palette.length)];
    final center = Offset(
      size.width * (0.08 + random.nextDouble() * 0.84),
      size.height * (0.08 + random.nextDouble() * 0.84),
    );
    final radius = size.shortestSide * (0.025 + random.nextDouble() * 0.095);
    final alpha = 0.10 + random.nextDouble() * 0.20;
    final kind = random.nextInt(4);
    if (kind == 0) {
      _vhwCircle(canvas, center, radius, color, alpha: alpha);
    } else if (kind == 1) {
      _vhwCircle(
        canvas,
        center,
        radius,
        color,
        alpha: alpha + 0.08,
        fill: false,
        strokeWidth: 1.2 + random.nextDouble() * 2.2,
      );
    } else if (kind == 2) {
      _vhwLine(
        canvas,
        center,
        center +
            Offset(
              (random.nextDouble() - 0.5) * size.width * 0.34,
              (random.nextDouble() - 0.5) * size.height * 0.34,
            ),
        color,
        1 + random.nextDouble() * 3,
        alpha: alpha,
      );
    } else {
      final path = Path();
      final sides = 3 + random.nextInt(4);
      for (var side = 0; side < sides; side++) {
        final angle = side / sides * math.pi * 2 + random.nextDouble() * 0.3;
        final point =
            center + Offset(math.cos(angle), math.sin(angle)) * radius;
        if (side == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = _vhwAlpha(color, alpha));
    }
  }

  // 一条贯穿画面的细弧线，给随机构图一个视觉主轴。
  final arcRect = Rect.fromCenter(
    center: Offset(size.width * 0.54, size.height * 0.52),
    width: size.width * 0.72,
    height: size.height * 0.72,
  );
  canvas.drawArc(
    arcRect,
    math.pi * 0.12,
    math.pi * 1.15,
    false,
    Paint()
      ..color = _vhwAlpha(const Color(0xFFB8CBFF), 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );

  _vhwVignette(canvas, size, strength: 0.48);
}
