// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter/material.dart';

import '../bili/models.dart';

class DanmakuSettings {
  final bool enabled;
  final double opacity;
  final double scale;
  final double speed;
  final double area;

  const DanmakuSettings({
    required this.enabled,
    required this.opacity,
    required this.scale,
    required this.speed,
    required this.area,
  });
}

/// 弹幕设置弹窗
class DanmakuSettingsDialog extends StatefulWidget {
  const DanmakuSettingsDialog({
    super.key,
    required this.enabled,
    required this.opacity,
    required this.scale,
    required this.speed,
    required this.area,
  });

  final bool enabled;
  final double opacity;
  final double scale;
  final double speed;
  final double area;

  @override
  State<DanmakuSettingsDialog> createState() => _DanmakuSettingsDialogState();
}

class _DanmakuSettingsDialogState extends State<DanmakuSettingsDialog> {
  late bool _enabled = widget.enabled;
  late double _opacity = widget.opacity;
  late double _scale = widget.scale;
  late double _speed = widget.speed;
  late double _area = widget.area;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF171A20),
      title: const Text('弹幕设置', style: TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('显示弹幕', style: TextStyle(fontSize: 13)),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            _slider('不透明度', _opacity, 0.2, 1.0, (value) {
              setState(() => _opacity = value);
            }, '${(_opacity * 100).round()}%'),
            _slider('字号', _scale, 0.6, 1.6, (value) {
              setState(() => _scale = value);
            }, '${(_scale * 100).round()}%'),
            _slider('滚动速度', _speed, 0.5, 2.5, (value) {
              setState(() => _speed = value);
            }, '${_speed.toStringAsFixed(1)}x'),
            const SizedBox(height: 6),
            const Text('显示区域', style: TextStyle(fontSize: 12, color: Color(0xFF8B9099))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final option in const [0.25, 0.5, 0.75, 1.0])
                  ChoiceChip(
                    label: Text(
                      option == 1.0 ? '全屏' : '${(option * 100).round()}%',
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: (_area - option).abs() < 0.01,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _area = option),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(DanmakuSettings(
            enabled: _enabled,
            opacity: _opacity,
            scale: _scale,
            speed: _speed,
            area: _area,
          )),
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _slider(String label, double value, double min, double max,
      ValueChanged<double> onChanged, String display) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8B9099))),
            const Spacer(),
            Text(display, style: const TextStyle(fontSize: 11, color: Color(0xFFC9CDD4))),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// 发送弹幕弹窗：返回输入内容，取消返回 null
class DanmakuInputDialog extends StatefulWidget {
  const DanmakuInputDialog({super.key, required this.position});

  final Duration position;

  @override
  State<DanmakuInputDialog> createState() => _DanmakuInputDialogState();
}

class _DanmakuInputDialogState extends State<DanmakuInputDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF171A20),
      title: Text(
        '发送弹幕 · ${formatSeconds(widget.position.inSeconds)}',
        style: const TextStyle(fontSize: 15),
      ),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 100,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: '发一条友善的弹幕吧',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            final text = value.trim();
            if (text.isNotEmpty) Navigator.of(context).pop(text);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) return;
            Navigator.of(context).pop(text);
          },
          child: const Text('发送'),
        ),
      ],
    );
  }
}
