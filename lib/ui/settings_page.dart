// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:async';

import 'package:flutter/material.dart';

import '../bili/prefs.dart';
import 'font_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.prefs, this.onBack});

  final AppPrefs prefs;
  final VoidCallback? onBack;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(
      widget.prefs.load().then((_) {
        if (mounted) setState(() {});
      }),
    );
  }

  void _apply(void Function() update) {
    setState(update);
    unawaited(widget.prefs.save());
  }

  void _setFontDelta(int value) {
    final delta = value.clamp(-4, 12);
    _apply(() {
      widget.prefs.fontDelta = delta;
      FontSettings.instance.restore(delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF0E1117),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              if (widget.onBack != null) ...[
                IconButton(
                  tooltip: '返回',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back, size: 19),
                ),
                const SizedBox(width: 4),
              ],
              const Text(
                '设置',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '外观、播放、弹幕、下载与视频来源',
            style: TextStyle(fontSize: 12, color: const Color(0xFF8B9099)),
          ),
          const SizedBox(height: 20),
          _section(
            context,
            icon: Icons.text_fields,
            title: '外观',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('全局字号'),
                subtitle: Text('当前 ${14 + widget.prefs.fontDelta}px，点击数值可重置'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '缩小字体',
                      onPressed: widget.prefs.fontDelta <= -4
                          ? null
                          : () => _setFontDelta(widget.prefs.fontDelta - 1),
                      icon: const Icon(Icons.text_decrease),
                    ),
                    ActionChip(
                      label: Text('${14 + widget.prefs.fontDelta}px'),
                      onPressed: () => _setFontDelta(0),
                    ),
                    IconButton(
                      tooltip: '放大字体',
                      onPressed: widget.prefs.fontDelta >= 12
                          ? null
                          : () => _setFontDelta(widget.prefs.fontDelta + 1),
                      icon: const Icon(Icons.text_increase),
                    ),
                  ],
                ),
              ),
              Slider(
                min: -4,
                max: 12,
                divisions: 16,
                value: widget.prefs.fontDelta.toDouble(),
                onChanged: (value) => _setFontDelta(value.round()),
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.play_circle_outline,
            title: '播放',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('默认音量'),
                subtitle: Text('${widget.prefs.volume.round()}%'),
                trailing: SizedBox(
                  width: 220,
                  child: Slider(
                    value: widget.prefs.volume.clamp(0, 100),
                    max: 100,
                    onChanged: (value) =>
                        _apply(() => widget.prefs.volume = value),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('画面适配', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in const {
                    'contain': '适应',
                    'cover': '裁剪',
                    'fill': '拉伸',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: widget.prefs.fit == entry.key,
                      onSelected: (_) =>
                          _apply(() => widget.prefs.fit = entry.key),
                    ),
                ],
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.subtitles,
            title: '弹幕',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('默认开启弹幕'),
                value: widget.prefs.danmakuOn,
                onChanged: (value) =>
                    _apply(() => widget.prefs.danmakuOn = value),
              ),
              _sliderTile(
                title: '透明度',
                value: widget.prefs.danmakuOpacity,
                onChanged: (value) =>
                    _apply(() => widget.prefs.danmakuOpacity = value),
              ),
              _sliderTile(
                title: '字号',
                value: widget.prefs.danmakuScale,
                min: 0.5,
                max: 2,
                onChanged: (value) =>
                    _apply(() => widget.prefs.danmakuScale = value),
              ),
              _sliderTile(
                title: '速度',
                value: widget.prefs.danmakuSpeed,
                min: 0.5,
                max: 2,
                onChanged: (value) =>
                    _apply(() => widget.prefs.danmakuSpeed = value),
              ),
              _sliderTile(
                title: '显示区域',
                value: widget.prefs.danmakuArea,
                min: 0.25,
                max: 1,
                onChanged: (value) =>
                    _apply(() => widget.prefs.danmakuArea = value),
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.download,
            title: '下载',
            children: [
              DropdownButtonFormField<int>(
                initialValue: widget.prefs.downloadQualityId,
                decoration: const InputDecoration(labelText: '默认画质'),
                items: const [
                  DropdownMenuItem(value: -1, child: Text('每次询问')),
                  DropdownMenuItem(value: 16, child: Text('360P')),
                  DropdownMenuItem(value: 64, child: Text('720P')),
                  DropdownMenuItem(value: 80, child: Text('1080P')),
                  DropdownMenuItem(value: 116, child: Text('1080P 高码率')),
                  DropdownMenuItem(value: 120, child: Text('4K')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _apply(() => widget.prefs.downloadQualityId = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('下载线程数'),
                subtitle: Text('${widget.prefs.downloadThreads} 个线程'),
                trailing: SizedBox(
                  width: 220,
                  child: Slider(
                    min: 1,
                    max: 16,
                    divisions: 15,
                    value: widget.prefs.downloadThreads.toDouble(),
                    onChanged: (value) => _apply(
                      () => widget.prefs.downloadThreads = value.round(),
                    ),
                  ),
                ),
              ),
              DropdownButtonFormField<int>(
                initialValue: widget.prefs.downloadSpeedLimit,
                decoration: const InputDecoration(labelText: '下载限速'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('不限速')),
                  DropdownMenuItem(value: 1024 * 1024, child: Text('1 MB/s')),
                  DropdownMenuItem(
                    value: 3 * 1024 * 1024,
                    child: Text('3 MB/s'),
                  ),
                  DropdownMenuItem(
                    value: 5 * 1024 * 1024,
                    child: Text('5 MB/s'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _apply(() => widget.prefs.downloadSpeedLimit = value);
                  }
                },
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.public,
            title: '视频来源',
            children: [
              const ListTile(
                leading: CircleAvatar(child: Icon(Icons.play_arrow)),
                title: Text('哔哩哔哩'),
                subtitle: Text('当前已接入 · 支持完整功能'),
                trailing: Icon(Icons.check_circle, color: Color(0xFF69DB7C)),
              ),
              const ListTile(
                leading: CircleAvatar(child: Icon(Icons.smart_display)),
                title: Text('YouTube'),
                subtitle: Text('接口与播放方案已预留，尚未接入'),
                trailing: Chip(label: Text('规划中')),
              ),
              const SizedBox(height: 8),
              Text(
                '新平台将通过统一 VideoSource 接口接入，不会在主页中增加平台分支。',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      color: const Color(0xFF141820),
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2A313E)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF9FB0FF)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _sliderTile({
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
    double min = 0,
    double max = 1,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(value.toStringAsFixed(2)),
      trailing: SizedBox(
        width: 220,
        child: Slider(
          min: min,
          max: max,
          value: value.clamp(min, max),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
