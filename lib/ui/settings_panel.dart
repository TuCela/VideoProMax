// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:async';

import 'package:flutter/material.dart';

import '../bili/prefs.dart';
import 'wallpaper.dart';

/// 点击左下角设置按钮弹出的紧凑壁纸面板（约 320×426）。
///
/// 只承载壁纸相关设置；字号、播放、弹幕、下载等仍在 [SettingsPage] 整页里。
class WallpaperSettingsPanel extends StatefulWidget {
  const WallpaperSettingsPanel({
    super.key,
    required this.prefs,
    required this.onClose,
    required this.onOpenFullSettings,
  });

  final AppPrefs prefs;
  final VoidCallback onClose;
  final VoidCallback onOpenFullSettings;

  @override
  State<WallpaperSettingsPanel> createState() => _WallpaperSettingsPanelState();
}

class _WallpaperSettingsPanelState extends State<WallpaperSettingsPanel> {
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

  Widget _wallpaperTile(WallpaperStyle style) {
    final selected = widget.prefs.wallpaperId == style.id;
    final isDay = style.dayNight && _previewIsDay(style);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _apply(() {
        widget.prefs.wallpaperId = style.id;
        _syncWallpaper();
      }),
      child: Container(
        width: 143,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF141820),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF5B8CFF) : const Color(0xFF2A313E),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 36,
                width: double.infinity,
                child: WallpaperCanvas(
                  style: style,
                  isDay: isDay,
                  intensity: 0.92,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  style.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE6E9F0),
                  ),
                ),
                if (style.dayNight) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2A4A),
                      borderRadius: BorderRadius.circular(3),
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
                    size: 12,
                    color: Color(0xFF5B8CFF),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayNightSwitch() {
    final on = widget.prefs.wallpaperAuto;
    return GestureDetector(
      onTap: () => _apply(() {
        widget.prefs.wallpaperAuto = !on;
        _syncWallpaper();
      }),
      child: Container(
        width: 30,
        height: 17,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF5B8CFF) : const Color(0xFF2A313E),
          borderRadius: BorderRadius.circular(9),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 140),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: SizedBox(width: 13, height: 13),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0B0E14),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 42,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B2433),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Text(
                      '设',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9FB0FF)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '设置',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE6E9F0),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '即时生效',
                    style: TextStyle(fontSize: 10, color: Color(0xFF657086)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: widget.onClose,
                    icon: const Icon(
                      Icons.close,
                      size: 15,
                      color: Color(0xFF8B9099),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(width: 20, height: 20),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A313E)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '壁纸',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE6E9F0),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '点击缩略图即时预览 · 自动保存',
                    style: TextStyle(fontSize: 10, color: Color(0xFF8B9099)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final style in kWallpaperStyles) _wallpaperTile(style),
                    ],
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => _apply(() {
                      widget.prefs.wallpaperId = '';
                      _syncWallpaper();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: widget.prefs.wallpaperId.isEmpty
                            ? const Color(0xFF1B2A4A)
                            : const Color(0xFF141820),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.prefs.wallpaperId.isEmpty
                              ? const Color(0xFF5B8CFF)
                              : const Color(0xFF2A313E),
                        ),
                      ),
                      child: Text(
                        '关闭壁纸 · 只用纯底色',
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.prefs.wallpaperId.isEmpty
                              ? const Color(0xFFB8CBFF)
                              : const Color(0xFF8B9099),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFF2A313E)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text(
                        '背景强度',
                        style: TextStyle(fontSize: 11, color: Color(0xFFE6E9F0)),
                      ),
                      const Spacer(),
                      Text(
                        widget.prefs.wallpaperIntensity.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9FB0FF),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    min: 0,
                    max: 0.7,
                    value: widget.prefs.wallpaperIntensity.clamp(0.0, 0.7),
                    onChanged: (value) => _apply(() {
                      widget.prefs.wallpaperIntensity = value;
                      _syncWallpaper();
                    }),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '跟随时间切换日间 / 夜间',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFE6E9F0),
                          ),
                        ),
                      ),
                      _dayNightSwitch(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '7:00–19:00 日间',
                    style: TextStyle(fontSize: 10, color: Color(0xFF657086)),
                  ),
                  if (!widget.prefs.wallpaperAuto &&
                      (wallpaperStyleById(widget.prefs.wallpaperId)?.dayNight ??
                          false)) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final entry
                            in const {false: '夜间', true: '日间'}.entries)
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
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFF2A313E)),
          InkWell(
            onTap: widget.onOpenFullSettings,
            child: SizedBox(
              height: 36,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Text(
                      '完整设置',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9FB0FF)),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward,
                      size: 13,
                      color: Color(0xFF9FB0FF),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
