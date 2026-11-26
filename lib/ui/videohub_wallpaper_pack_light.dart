// VideoHub 八款原生浅色代码壁纸
//
// 这一版不使用深色壁纸作为底图，也不叠白色半透明蒙层。
// 所有颜色、对比度和构图都按浅色背景重新设计。
//
// 接入方式：
// 1. 放入 lib/ui/videohub_wallpaper_pack_light.dart；
// 2. 在 wallpaper.dart 中导入；
// 3. 将 kVideoHubNativeLightWallpaperSpecs 映射为 WallpaperStyle；
// 4. 为浅色 style 使用 #F7F8FA / #FFFEFA 类浅色底板，并设置较高不透明度。
//
// 全部由 Canvas / Path / Paint 绘制，无外部图片、字体或网络依赖。

import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef VideoHubNativeLightPaint = void Function(
  Canvas canvas,
  Size size,
  bool isDay,
);

class VideoHubNativeLightSpec {
  const VideoHubNativeLightSpec({
    required this.id,
    required this.name,
    required this.desc,
    required this.paint,
    required this.recommendedOpacity,
  });

  final String id;
  final String name;
  final String desc;
  final VideoHubNativeLightPaint paint;
  final double recommendedOpacity;
}

const List<VideoHubNativeLightSpec> kVideoHubNativeLightWallpaperSpecs = [
  VideoHubNativeLightSpec(
    id: 'cyberpunk_light',
    name: '赛博朋克 · 白',
    desc: '粉青霓虹城市、浅色天际线与明亮网格',
    paint: paintNativeLightCyberpunk,
    recommendedOpacity: 0.94,
  ),
  VideoHubNativeLightSpec(
    id: 'ink_light',
    name: '水墨国风 · 白',
    desc: '宣纸、淡墨远山、朱砂与竹叶',
    paint: paintNativeLightInk,
    recommendedOpacity: 0.96,
  ),
  VideoHubNativeLightSpec(
    id: 'brush_light',
    name: '插画笔刷 · 白',
    desc: '奶油纸底、粉彩笔触与干扫线条',
    paint: paintNativeLightBrush,
    recommendedOpacity: 0.94,
  ),
  VideoHubNativeLightSpec(
    id: 'minimal_light',
    name: '极简 · 白',
    desc: '暖白底、清晰几何与低饱和点缀',
    paint: paintNativeLightMinimal,
    recommendedOpacity: 0.98,
  ),
  VideoHubNativeLightSpec(
    id: 'bauhaus_light',
    name: '包豪斯 · 白',
    desc: '白色画布、三原色构成与严格网格',
    paint: paintNativeLightBauhaus,
    recommendedOpacity: 0.96,
  ),
  VideoHubNativeLightSpec(
    id: 'vaporwave_light',
    name: '蒸气波 · 白',
    desc: '浅粉紫落日、青色网格与柔和棕榈',
    paint: paintNativeLightVaporwave,
    recommendedOpacity: 0.94,
  ),
  VideoHubNativeLightSpec(
    id: 'lowpoly_light',
    name: '低多边形 · 白',
    desc: '冰白底、清晰浅蓝灰三角切面',
    paint: paintNativeLightLowPoly,
    recommendedOpacity: 0.96,
  ),
  VideoHubNativeLightSpec(
    id: 'random_light',
    name: '随机 · 白',
    desc: '暖白底、粉彩几何与清晰随机构成',
    paint: paintNativeLightRandom,
    recommendedOpacity: 0.94,
  ),
];

Color _a(Color color, double alpha) =>
    color.withValues(alpha: alpha.clamp(0.0, 1.0));

void _fill(
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

void _glow(
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
          _a(color, color.a * alpha),
          _a(color, color.a * alpha * 0.45),
          _a(color, 0),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(rect),
  );
}

void _line(
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
      ..color = _a(color, alpha)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
}

void _circle(
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
      ..color = _a(color, alpha)
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = strokeWidth,
  );
}

void _edgeTint(Canvas canvas, Size size, Color color, {double alpha = 0.16}) {
  final rect = Offset.zero & size;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.82,
        colors: [Colors.transparent, _a(color, alpha * 0.25), _a(color, alpha)],
        stops: const [0, 0.62, 1],
      ).createShader(rect),
  );
}

void _mountain(
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
  const steps = 48;
  for (var i = 0; i <= steps; i++) {
    final t = i / steps;
    final x = t * size.width;
    final ridge =
        baseY -
        amplitude *
            (0.30 + 0.70 * math.sin(t * math.pi * 3.2 + phase).abs()) *
            (0.78 + 0.22 * math.sin(t * math.pi * 8.0 + phase));
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
      ..color = _a(color, alpha)
      ..maskFilter = blur > 0 ? MaskFilter.blur(BlurStyle.normal, blur) : null,
  );
}

// ------------------------------------------------------------------ 赛博朋克

void paintNativeLightCyberpunk(Canvas canvas, Size size, bool isDay) {
  _fill(canvas, size, const [
    Color(0xFFF8FBFF),
    Color(0xFFEAF1FA),
    Color(0xFFFBF4FC),
  ]);

  _glow(
    canvas,
    size,
    center: Offset(size.width * 0.15, size.height * 0.20),
    radius: size.shortestSide * 0.52,
    color: const Color(0xFF71D5E5),
    alpha: 0.26,
  );
  _glow(
    canvas,
    size,
    center: Offset(size.width * 0.86, size.height * 0.72),
    radius: size.shortestSide * 0.56,
    color: const Color(0xFFF0A3C8),
    alpha: 0.24,
  );

  final random = math.Random(2077);
  const cyan = Color(0xFF55B9CC);
  const magenta = Color(0xFFD879A7);
  final horizon = size.height * 0.64;

  var x = -18.0;
  while (x < size.width) {
    final width = 28 + random.nextDouble() * 56;
    final height = size.height * (0.10 + random.nextDouble() * 0.25);
    final top = horizon - height;
    final rect = Rect.fromLTWH(x, top, width, height);
    canvas.drawRect(
      rect,
      Paint()
        ..color = _a(const Color(0xFFFDFEFF), 0.82)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..color = _a(random.nextBool() ? cyan : magenta, 0.46)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    final cols = math.max(2, (width / 13).floor());
    final rows = math.max(3, (height / 16).floor());
    for (var row = 1; row < rows; row++) {
      for (var col = 1; col < cols; col++) {
        if (random.nextDouble() > 0.54) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            x + col * width / cols,
            top + row * height / rows,
            2.8,
            3.6,
          ),
          Paint()
            ..color = _a(
              random.nextBool() ? cyan : magenta,
              0.42 + random.nextDouble() * 0.35,
            ),
        );
      }
    }
    x += width + 6 + random.nextDouble() * 8;
  }

  for (var i = -7; i <= 7; i++) {
    _line(
      canvas,
      Offset(size.width * 0.5 + i * 8, horizon),
      Offset(size.width * 0.5 + i * size.width * 0.11, size.height),
      i.isEven ? cyan : magenta,
      1,
      alpha: 0.24,
    );
  }
  for (var i = 1; i <= 7; i++) {
    final t = i / 7;
    final y = horizon + (size.height - horizon) * t * t;
    _line(
      canvas,
      Offset(0, y),
      Offset(size.width, y),
      cyan,
      1,
      alpha: 0.14 + t * 0.12,
    );
  }

  _line(
    canvas,
    Offset(size.width * 0.04, size.height * 0.44),
    Offset(size.width * 0.42, size.height * 0.10),
    cyan,
    2.2,
    alpha: 0.56,
  );
  _line(
    canvas,
    Offset(size.width * 0.62, size.height * 0.94),
    Offset(size.width * 0.98, size.height * 0.52),
    magenta,
    2.2,
    alpha: 0.52,
  );

  _edgeTint(canvas, size, const Color(0xFFB8C8E2), alpha: 0.20);
}

// ------------------------------------------------------------------ 水墨

void paintNativeLightInk(Canvas canvas, Size size, bool isDay) {
  _fill(
    canvas,
    size,
    const [Color(0xFFFCFAF4), Color(0xFFF5F1E8), Color(0xFFFBF9F3)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  _circle(
    canvas,
    Offset(size.width * 0.74, size.height * 0.27),
    size.shortestSide * 0.082,
    const Color(0xFFD45F55),
    alpha: 0.78,
  );

  _mountain(
    canvas,
    size,
    size.height * 0.58,
    size.height * 0.27,
    const Color(0xFFA9B5B1),
    0.30,
    blur: 14,
    phase: 0.7,
  );
  _mountain(
    canvas,
    size,
    size.height * 0.70,
    size.height * 0.24,
    const Color(0xFF7F9591),
    0.46,
    blur: 5,
    phase: 2.1,
  );
  _mountain(
    canvas,
    size,
    size.height * 0.84,
    size.height * 0.19,
    const Color(0xFF526F6B),
    0.66,
    phase: 4.4,
  );

  for (var i = 0; i < 3; i++) {
    final y = size.height * (0.54 + i * 0.09);
    canvas.drawRect(
      Rect.fromLTWH(0, y - 10, size.width, 24),
      Paint()
        ..color = _a(const Color(0xFFFFFFFF), 0.56)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }

  final bamboo = Paint()
    ..color = _a(const Color(0xFF4F6C63), 0.76)
    ..strokeWidth = 2.2
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
      final x = baseX + (topX - baseX) * (1 - y / size.height);
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

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.88,
        size.height * 0.82,
        size.shortestSide * 0.036,
        size.shortestSide * 0.036,
      ),
      const Radius.circular(2),
    ),
    Paint()..color = _a(const Color(0xFFC44B43), 0.78),
  );

  _edgeTint(canvas, size, const Color(0xFFC9BDA8), alpha: 0.18);
}

// ------------------------------------------------------------------ 插画笔刷

void paintNativeLightBrush(Canvas canvas, Size size, bool isDay) {
  _fill(canvas, size, const [
    Color(0xFFFFFBF5),
    Color(0xFFFBF2E9),
    Color(0xFFF7F4F0),
  ]);

  final strokes = <({Color color, double width, double phase})>[
    (color: const Color(0xFFE3A45F), width: 0.17, phase: 0.2),
    (color: const Color(0xFF69AAA8), width: 0.14, phase: 1.8),
    (color: const Color(0xFFCC7896), width: 0.16, phase: 3.2),
  ];

  for (final stroke in strokes) {
    final path = Path();
    const steps = 60;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = -size.width * 0.10 + t * size.width * 1.20;
      final y =
          size.height * (0.26 + stroke.phase * 0.11) +
          math.sin(t * math.pi * 2.1 + stroke.phase) *
              size.height *
              stroke.width *
              0.40;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _a(stroke.color, 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (var i = 0; i < 6; i++) {
      canvas.save();
      canvas.translate(0, (i - 2.5) * size.shortestSide * 0.011);
      canvas.drawPath(
        path,
        Paint()
          ..color = _a(stroke.color, 0.20 + i * 0.025)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
      canvas.restore();
    }
  }

  final random = math.Random(brushLightSeed);
  for (var i = 0; i < 34; i++) {
    final radius = 1.5 + random.nextDouble() * size.shortestSide * 0.016;
    _circle(
      canvas,
      Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      ),
      radius,
      i.isEven ? const Color(0xFFD58A4F) : const Color(0xFF4F9694),
      alpha: 0.20 + random.nextDouble() * 0.28,
    );
  }

  // 轻微纸纹点，保持低频，不干扰阅读。
  for (var i = 0; i < 90; i++) {
    _circle(
      canvas,
      Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      ),
      0.45,
      const Color(0xFF9C8F80),
      alpha: 0.10,
    );
  }

  _edgeTint(canvas, size, const Color(0xFFD8C8B8), alpha: 0.16);
}

// ------------------------------------------------------------------ 极简

void paintNativeLightMinimal(Canvas canvas, Size size, bool isDay) {
  _fill(canvas, size, const [
    Color(0xFFFAFBFD),
    Color(0xFFF2F5F9),
    Color(0xFFFAFBFD),
  ]);

  _circle(
    canvas,
    Offset(size.width * 0.72, size.height * 0.30),
    size.shortestSide * 0.17,
    const Color(0xFF789BE0),
    alpha: 0.68,
    fill: false,
    strokeWidth: 1.8,
  );
  _circle(
    canvas,
    Offset(size.width * 0.24, size.height * 0.72),
    size.shortestSide * 0.034,
    const Color(0xFF72B89B),
    alpha: 0.82,
  );
  _line(
    canvas,
    Offset(size.width * 0.16, size.height * 0.58),
    Offset(size.width * 0.48, size.height * 0.58),
    const Color(0xFF9AA8BB),
    1.2,
    alpha: 0.70,
  );
  _line(
    canvas,
    Offset(size.width * 0.16, size.height * 0.58),
    Offset(size.width * 0.16, size.height * 0.74),
    const Color(0xFF9AA8BB),
    1.2,
    alpha: 0.58,
  );

  _edgeTint(canvas, size, const Color(0xFFCAD5E5), alpha: 0.20);
}

// ------------------------------------------------------------------ 包豪斯

void paintNativeLightBauhaus(Canvas canvas, Size size, bool isDay) {
  _fill(canvas, size, const [
    Color(0xFFFCFCF9),
    Color(0xFFF7F7F2),
    Color(0xFFFCFCF9),
  ]);

  const red = Color(0xFFDB6F70);
  const yellow = Color(0xFFE2BE55);
  const blue = Color(0xFF5F83D6);
  final unit = size.shortestSide;

  _circle(
    canvas,
    Offset(size.width * 0.18, size.height * 0.24),
    unit * 0.12,
    blue,
    alpha: 0.84,
  );

  canvas.drawRect(
    Rect.fromLTWH(
      size.width * 0.70,
      size.height * 0.12,
      size.width * 0.16,
      size.height * 0.20,
    ),
    Paint()..color = _a(red, 0.82),
  );

  final triangle = Path()
    ..moveTo(size.width * 0.10, size.height * 0.82)
    ..lineTo(size.width * 0.30, size.height * 0.58)
    ..lineTo(size.width * 0.34, size.height * 0.84)
    ..close();
  canvas.drawPath(triangle, Paint()..color = _a(yellow, 0.86));

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
  canvas.drawPath(semicircle, Paint()..color = _a(blue, 0.72));

  _line(
    canvas,
    Offset(size.width * 0.38, size.height * 0.12),
    Offset(size.width * 0.38, size.height * 0.88),
    const Color(0xFF3B4350),
    1,
    alpha: 0.42,
  );
  _line(
    canvas,
    Offset(size.width * 0.08, size.height * 0.48),
    Offset(size.width * 0.92, size.height * 0.48),
    const Color(0xFF3B4350),
    1,
    alpha: 0.32,
  );
  _line(
    canvas,
    Offset(size.width * 0.52, size.height * 0.16),
    Offset(size.width * 0.68, size.height * 0.40),
    red,
    3,
    alpha: 0.72,
  );

  _edgeTint(canvas, size, const Color(0xFFD8D4C8), alpha: 0.18);
}

// ------------------------------------------------------------------ 蒸气波

void paintNativeLightVaporwave(Canvas canvas, Size size, bool isDay) {
  _fill(
    canvas,
    size,
    const [Color(0xFFFFF0F8), Color(0xFFEAF8FF), Color(0xFFF8F2FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  final random = math.Random(vaporLightSeed);
  for (var i = 0; i < 76; i++) {
    _circle(
      canvas,
      Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height * 0.58,
      ),
      0.7 + random.nextDouble() * 1.2,
      const Color(0xFFB9A7D6),
      alpha: 0.28 + random.nextDouble() * 0.30,
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
          _a(const Color(0xFFFFD989), 0.96),
          _a(const Color(0xFFF5A0C2), 0.90),
        ],
      ).createShader(sunRect),
  );

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
      Paint()..color = _a(const Color(0xFFF6EAF7), 0.88),
    );
  }

  final horizon = size.height * 0.62;
  for (var i = -8; i <= 8; i++) {
    _line(
      canvas,
      Offset(size.width * 0.5 + i * 6, horizon),
      Offset(size.width * 0.5 + i * size.width * 0.13, size.height),
      const Color(0xFF64C6D8),
      1,
      alpha: 0.36,
    );
  }
  for (var i = 1; i <= 9; i++) {
    final t = i / 9;
    final y = horizon + (size.height - horizon) * t * t;
    _line(
      canvas,
      Offset(0, y),
      Offset(size.width, y),
      const Color(0xFFC798DD),
      1,
      alpha: 0.24 + t * 0.18,
    );
  }

  final palm = Paint()
    ..color = _a(const Color(0xFF8D9DB9), 0.76)
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  for (final side in [-1, 1]) {
    final baseX = size.width * (side < 0 ? 0.10 : 0.90);
    final topX = baseX + side * size.width * 0.035;
    final topY = size.height * 0.46;
    canvas.drawLine(Offset(baseX, horizon), Offset(topX, topY), palm);
    for (var i = 0; i < 6; i++) {
      final angle = -math.pi * 0.92 + i * math.pi * 0.184;
      final length = size.shortestSide * 0.13;
      canvas.drawLine(
        Offset(topX, topY),
        Offset(
          topX + math.cos(angle) * length,
          topY + math.sin(angle) * length * 0.55,
        ),
        palm..strokeWidth = 2.6,
      );
    }
  }

  _edgeTint(canvas, size, const Color(0xFFD6C9E8), alpha: 0.20);
}

// ------------------------------------------------------------------ 低多边形

void paintNativeLightLowPoly(Canvas canvas, Size size, bool isDay) {
  _fill(canvas, size, const [
    Color(0xFFFAFCFF),
    Color(0xFFEDF4FA),
    Color(0xFFFAFCFF),
  ]);

  _glow(
    canvas,
    size,
    center: Offset(size.width * 0.66, size.height * 0.34),
    radius: size.shortestSide * 0.58,
    color: const Color(0xFFA9C9F0),
    alpha: 0.22,
  );

  final random = math.Random(lowPolyLightSeed);
  const palette = [
    Color(0xFFDCE8F6),
    Color(0xFFC8DAF0),
    Color(0xFFD8D4EE),
    Color(0xFFC4E1E1),
    Color(0xFFE8EDF5),
    Color(0xFFD2E0EC),
  ];
  final cell = size.shortestSide / 5.0;
  final cols = (size.width / cell).ceil() + 2;
  final rows = (size.height / cell).ceil() + 2;
  final points = <List<Offset>>[];
  for (var row = 0; row < rows; row++) {
    final list = <Offset>[];
    for (var col = 0; col < cols; col++) {
      list.add(
        Offset(
          (col - 1) * cell + (random.nextDouble() - 0.5) * cell * 0.70,
          (row - 1) * cell + (random.nextDouble() - 0.5) * cell * 0.70,
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
      for (final triangle in [
        [a, b, c],
        [b, d, c],
      ]) {
        final path = Path()
          ..moveTo(triangle[0].dx, triangle[0].dy)
          ..lineTo(triangle[1].dx, triangle[1].dy)
          ..lineTo(triangle[2].dx, triangle[2].dy)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = _a(
              palette[random.nextInt(palette.length)],
              0.72 + random.nextDouble() * 0.22,
            )
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = _a(const Color(0xFFAABBD0), 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
    }
  }

  _edgeTint(canvas, size, const Color(0xFFBDD0E4), alpha: 0.22);
}

// ------------------------------------------------------------------ 随机

const int brushLightSeed = 20261126;
const int vaporLightSeed = 1984;
const int lowPolyLightSeed = 731;
const int randomLightSeed = 20261126;

void paintNativeLightRandom(Canvas canvas, Size size, bool isDay) {
  _fill(canvas, size, const [
    Color(0xFFFDFCF9),
    Color(0xFFF6F4F0),
    Color(0xFFFDFCF9),
  ]);

  final random = math.Random(randomLightSeed);
  const palette = [
    Color(0xFF8EACE8),
    Color(0xFFB79ADD),
    Color(0xFF78BDB8),
    Color(0xFFDB91A8),
    Color(0xFFDFC16B),
    Color(0xFF92BEA0),
  ];

  for (var i = 0; i < 24; i++) {
    final color = palette[random.nextInt(palette.length)];
    final center = Offset(
      size.width * (0.08 + random.nextDouble() * 0.84),
      size.height * (0.08 + random.nextDouble() * 0.84),
    );
    final radius = size.shortestSide * (0.025 + random.nextDouble() * 0.090);
    final alpha = 0.46 + random.nextDouble() * 0.30;
    final kind = random.nextInt(4);
    if (kind == 0) {
      _circle(canvas, center, radius, color, alpha: alpha);
    } else if (kind == 1) {
      _circle(
        canvas,
        center,
        radius,
        color,
        alpha: alpha + 0.10,
        fill: false,
        strokeWidth: 1.5 + random.nextDouble() * 2.0,
      );
    } else if (kind == 2) {
      _line(
        canvas,
        center,
        center +
            Offset(
              (random.nextDouble() - 0.5) * size.width * 0.34,
              (random.nextDouble() - 0.5) * size.height * 0.34,
            ),
        color,
        1.5 + random.nextDouble() * 2.5,
        alpha: alpha,
      );
    } else {
      final path = Path();
      final sides = 3 + random.nextInt(4);
      for (var side = 0; side < sides; side++) {
        final angle = side / sides * math.pi * 2 + random.nextDouble() * 0.25;
        final point =
            center + Offset(math.cos(angle), math.sin(angle)) * radius;
        if (side == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = _a(color, alpha));
    }
  }

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
      ..color = _a(const Color(0xFF7F9CCF), 0.46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4,
  );

  _edgeTint(canvas, size, const Color(0xFFD8D3E6), alpha: 0.20);
}
