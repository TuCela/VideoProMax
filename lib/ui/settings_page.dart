// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:async';

import 'package:flutter/material.dart';

import '../app/window_chrome.dart';
import '../bili/prefs.dart';
import 'font_settings.dart';
import 'wallpaper.dart';
import 'surface_settings.dart';

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
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 顶部条：返回按钮单独放在拖动区之外，点击不会被拖窗手势抢；
          // 标题与右侧空白按住即可拖动窗口，双击最大化。
          SizedBox(
            height: 64,
            child: Row(
              children: [
                if (widget.onBack != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: IconButton(
                      tooltip: '返回',
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back, size: 19),
                    ),
                  ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (_) => WindowChrome.drag(),
                    onDoubleTap: () => WindowChrome.maximize(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          '设置',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              children: [
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
              const SizedBox(height: 8),
              _sliderTile(
                title: '内容底板不透明度',
                value: widget.prefs.surfaceOpacity,
                min: SurfaceSettings.minOpacity,
                max: SurfaceSettings.maxOpacity,
                onChanged: (value) => _apply(() {
                  widget.prefs.surfaceOpacity = value;
                  SurfaceSettings.instance.update(value);
                }),
              ),
              const Text(
                '正文面板的深色底板，越高越易读；与壁纸风格无关。',
                style: TextStyle(fontSize: 11, color: Color(0xFF8B9099)),
              ),
            ],
          ),
          _section(
            context,
            icon: Icons.wallpaper,
            title: '壁纸',
            children: [
              const Text(
                '背景由代码实时绘制，不依赖图片资源；深色 8 套、浅色 8 套，'
                '切换即时生效。浅色壁纸会自动换用浅色底板并把强度提到推荐值。',
                style: TextStyle(fontSize: 11, color: Color(0xFF8B9099)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _wallpaperTile(null),
                  for (final style in kWallpaperStyles) _wallpaperTile(style),
                ],
              ),
              const SizedBox(height: 4),
              _sliderTile(
                title: '背景强度',
                value: widget.prefs.wallpaperIntensity,
                // 浅色壁纸要接近全不透明才不发灰，上限放到 1.0；
                // 深色壁纸保持原来的 0.7。
                max: wallpaperStyleById(
                      widget.prefs.wallpaperId,
                    )?.maxIntensity ??
                    0.7,
                onChanged: (value) => _apply(() {
                  widget.prefs.wallpaperIntensity = value;
                  _syncWallpaper();
                }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('跟随时间切换日间 / 夜间'),
                subtitle: const Text('7:00-19:00 使用日间配色'),
                value: widget.prefs.wallpaperAuto,
                onChanged: (value) => _apply(() {
                  widget.prefs.wallpaperAuto = value;
                  _syncWallpaper();
                }),
              ),
              if (!widget.prefs.wallpaperAuto &&
                  (wallpaperStyleById(widget.prefs.wallpaperId)?.dayNight ??
                      false))
                Wrap(
                  spacing: 8,
                  children: [
                    for (final entry in const {false: '夜间', true: '日间'}.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: widget.prefs.wallpaperDay == entry.key,
                        onSelected: (_) => _apply(() {
                          widget.prefs.wallpaperDay = entry.key;
                          _syncWallpaper();
                        }),
                      ),
                  ],
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
          ),
        ],
      ),
    );
  }

  void _syncWallpaper() {
    final settings = WallpaperSettings.instance;
    settings.update(
      settings.state.value.copyWith(
        styleId: widget.prefs.wallpaperId,
        intensity: widget.prefs.wallpaperIntensity,
        auto: widget.prefs.wallpaperAuto,
        manualDay: widget.prefs.wallpaperDay,
      ),
    );
  }

  bool _previewIsDay(WallpaperStyle style) {
    if (!style.dayNight) return false;
    if (widget.prefs.wallpaperAuto) {
      final hour = DateTime.now().hour;
      return hour >= 7 && hour < 19;
    }
    return widget.prefs.wallpaperDay;
  }

  Widget _wallpaperTile(WallpaperStyle? style) {
    final id = style?.id ?? '';
    final selected = widget.prefs.wallpaperId == id;
    final dayNight = style?.dayNight ?? false;
    final isDay = dayNight && _previewIsDay(style!);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _apply(() {
        widget.prefs.wallpaperId = id;
        // 每套壁纸都有自己的最佳强度：切换时按推荐值初始化，
        // 否则浅色壁纸沿用深色的 0.40 会整幅发灰。
        final recommended = style?.recommendedOpacity;
        if (recommended != null) {
          widget.prefs.wallpaperIntensity = recommended;
        } else {
          // 原有 6 套没有推荐值，沿用当前强度但不能超过它自己的上限。
          widget.prefs.wallpaperIntensity = widget.prefs.wallpaperIntensity
              .clamp(0.0, style?.maxIntensity ?? 0.7);
        }
        _syncWallpaper();
      }),
      child: Container(
        width: 176,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: SurfaceSettings.instance.color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF5B8CFF) : const Color(0xFF2A313E),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 78,
                width: double.infinity,
                child: style == null
                    ? const ColoredBox(
                        color: Color(0xFF0B0E14),
                        child: Center(
                          child: Text(
                            '关闭',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF657086),
                            ),
                          ),
                        ),
                      )
                    : WallpaperCanvas(
                        style: style,
                        isDay: isDay,
                        intensity: 0.92,
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  style?.name ?? '纯色',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (dayNight) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2A4A),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '日/夜',
                      style: TextStyle(fontSize: 9, color: Color(0xFFB8CBFF)),
                    ),
                  ),
                ],
                const Spacer(),
                if (selected)
                  const Icon(
                    Icons.check_circle,
                    size: 13,
                    color: Color(0xFF5B8CFF),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              style?.desc ?? '只用纯底色，不绘制背景',
              maxLines: 2,
              style: const TextStyle(
                fontSize: 10,
                height: 1.35,
                color: Color(0xFF8B9099),
              ),
            ),
          ],
        ),
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
      color: SurfaceSettings.instance.color,
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
