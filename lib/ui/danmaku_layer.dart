import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../bili/models.dart';

/// 弹幕层：按播放位置绘制滚动/顶部/底部弹幕
class DanmakuLayer extends StatefulWidget {
  const DanmakuLayer({
    super.key,
    required this.items,
    required this.position,
    required this.playing,
    required this.enabled,
    required this.opacity,
    required this.fontScale,
    required this.speed,
    required this.area,
  });

  final List<DanmakuItem> items;
  final Duration position;
  final bool playing;
  final bool enabled;
  final double opacity;
  final double fontScale;
  final double speed;
  final double area;

  @override
  State<DanmakuLayer> createState() => _DanmakuLayerState();
}

class _LiveDanmaku {
  _LiveDanmaku({
    required this.item,
    required this.start,
    required this.duration,
    required this.y,
    required this.lane,
    required this.painter,
  });

  final DanmakuItem item;
  final double start;
  final double duration;
  final double y;
  final int lane;
  final TextPainter painter;

  double get width => painter.width;
}

class _DanmakuLayerState extends State<DanmakuLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> repaint = ValueNotifier<int>(0);
  final List<_LiveDanmaku> active = [];

  double clock = 0;
  double _basePosition = 0;
  DateTime _baseWall = DateTime.now();
  Duration _lastElapsed = Duration.zero;
  int _pointer = 0;
  Size _size = Size.zero;

  double get _lineHeight => 30 * widget.fontScale * 1.45;

  @override
  void initState() {
    super.initState();
    clock = widget.position.inMilliseconds / 1000;
    _basePosition = clock;
    _pointer = _lowerBound(clock - 0.2);
    _ticker = createTicker(_onTick);
    if (widget.playing) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant DanmakuLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.position != oldWidget.position) {
      final target = widget.position.inMilliseconds / 1000;
      _basePosition = target;
      _baseWall = DateTime.now();
      if ((target - clock).abs() > 0.6) {
        clock = target;
        _resetTo(target);
      } else {
        clock = target;
      }
    }
    if (widget.opacity != oldWidget.opacity ||
        widget.fontScale != oldWidget.fontScale ||
        widget.speed != oldWidget.speed ||
        widget.area != oldWidget.area) {
      _resetTo(clock);
    }
    if (widget.playing && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _ticker.start();
    } else if (!widget.playing && _ticker.isActive) {
      _ticker.stop();
    }
    if (!widget.playing) {
      clock = _basePosition;
    }
  }

  void _onTick(Duration elapsed) {
    final delta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    if (widget.playing) {
      final extra = delta.inMicroseconds / 1e6;
      if (extra > 0 && extra < 0.5) {
        clock = _basePosition + (DateTime.now().difference(_baseWall).inMicroseconds / 1e6);
      }
    }
    _sync();
    repaint.value++;
  }

  int _lowerBound(double time) {
    var low = 0;
    var high = widget.items.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (widget.items[mid].time < time) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  void _resetTo(double time) {
    active.clear();
    _pointer = _lowerBound(time - 0.2);
  }

  void _sync() {
    if (_size.width <= 0 || _size.height <= 0) return;
    while (_pointer < widget.items.length &&
        widget.items[_pointer].time <= clock) {
      final item = widget.items[_pointer];
      _pointer++;
      if (!widget.enabled) continue;
      if (clock - item.time > 1.2) continue;
      if (active.length >= 140) continue;
      _spawn(item);
    }
    active.removeWhere((live) => clock > live.start + live.duration);
  }

  void _spawn(DanmakuItem item) {
    final fontSize = (item.fontSize * widget.fontScale).clamp(14.0, 48.0);
    final color = Color(0xFF000000 | item.color).withValues(alpha: widget.opacity);
    final painter = TextPainter(
      text: TextSpan(
        text: item.text,
        style: TextStyle(
          fontSize: fontSize,
          height: 1.15,
          color: color,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.85),
              blurRadius: 2,
            ),
            Shadow(
              color: Colors.black.withValues(alpha: 0.85),
              blurRadius: 2,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final maxHeight = _size.height * widget.area.clamp(0.2, 1.0);
    final laneCount = (maxHeight / _lineHeight).floor().clamp(1, 24);

    if (item.isScroll) {
      final duration = 9 / widget.speed.clamp(0.4, 3.0);
      final lane = _pickScrollLane(laneCount);
      if (lane < 0) return;
      active.add(_LiveDanmaku(
        item: item,
        start: clock,
        duration: duration,
        y: lane * _lineHeight + 4,
        lane: lane,
        painter: painter,
      ));
    } else {
      final duration = 4.5;
      final isTop = item.mode == 5;
      final lane = _pickFixedLane(laneCount, isTop);
      if (lane < 0) return;
      active.add(_LiveDanmaku(
        item: item,
        start: clock,
        duration: duration,
        y: isTop ? lane * _lineHeight + 4 : _size.height * widget.area - (lane + 1) * _lineHeight,
        lane: isTop ? lane : -lane - 1,
        painter: painter,
      ));
    }
  }

  int _pickScrollLane(int laneCount) {
    for (var lane = 0; lane < laneCount; lane++) {
      var free = true;
      for (final live in active) {
        if (live.lane != lane || !live.item.isScroll) continue;
        final progress = (clock - live.start) / live.duration;
        final tail = _size.width - progress * (_size.width + live.width) + live.width;
        if (tail > _size.width - 10) {
          free = false;
          break;
        }
      }
      if (free) return lane;
    }
    return -1;
  }

  int _pickFixedLane(int laneCount, bool top) {
    for (var lane = 0; lane < laneCount; lane++) {
      final key = top ? lane : -lane - 1;
      var free = true;
      for (final live in active) {
        if (live.lane == key && clock < live.start + live.duration) {
          free = false;
          break;
        }
      }
      if (free) return lane;
    }
    return -1;
  }

  @override
  void dispose() {
    _ticker.dispose();
    repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return IgnorePointer(
          child: ClipRect(
            child: CustomPaint(
              painter: _DanmakuPainter(this),
              size: Size.infinite,
            ),
          ),
        );
      },
    );
  }
}

class _DanmakuPainter extends CustomPainter {
  _DanmakuPainter(this.state) : super(repaint: state.repaint);

  final _DanmakuLayerState state;

  @override
  void paint(Canvas canvas, Size size) {
    for (final live in state.active) {
      final progress = (state.clock - live.start) / live.duration;
      if (progress < 0 || progress > 1) continue;
      final double x;
      if (live.item.isScroll) {
        x = size.width - progress * (size.width + live.width);
      } else {
        x = (size.width - live.width) / 2;
      }
      if (x > size.width + 10 || x + live.width < -10) continue;
      live.painter.paint(canvas, Offset(x, live.y));
    }
  }

  @override
  bool shouldRepaint(covariant _DanmakuPainter oldDelegate) => true;
}
