// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bili/prefs.dart';
import '../ui/home_page.dart';
import '../ui/settings_panel.dart';
import '../ui/settings_page.dart';
import '../ui/wallpaper.dart';
import 'app_destination.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

AppDestination _initialDestination() {
  return switch (Platform.environment['VIDEOHUB_PAGE']) {
    'history' => AppDestination.history,
    'downloads' => AppDestination.downloads,
    'space' => AppDestination.space,
    'settings' => AppDestination.settings,
    _ => AppDestination.home,
  };
}

class _AppShellState extends State<AppShell> {
  final AppPrefs _prefs = AppPrefs();
  final ValueNotifier<AppDestination> _destination =
      ValueNotifier<AppDestination>(_initialDestination());
  final ValueNotifier<int> _downloadCount = ValueNotifier<int>(0);
  final ValueNotifier<bool> _settingsPanelOpen = ValueNotifier<bool>(false);

  Timer? _dayNightTimer;

  @override
  void initState() {
    super.initState();
    // 壁纸设置存在 prefs 里：先读配置，再让环境变量覆盖（截图/回归用）。
    unawaited(
      _prefs.load().then((_) {
        _syncWallpaper();
        WallpaperSettings.instance.applyEnvironmentOverride();
      }),
    );
    // 跟随时间切换日夜时，每 5 分钟重算一次，避免长时间挂机后不切换。
    _dayNightTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  void _syncWallpaper() {
    final settings = WallpaperSettings.instance;
    settings.update(
      settings.state.value.copyWith(
        styleId: _prefs.wallpaperId,
        intensity: _prefs.wallpaperIntensity,
        auto: _prefs.wallpaperAuto,
        manualDay: _prefs.wallpaperDay,
      ),
    );
  }

  @override
  void dispose() {
    _dayNightTimer?.cancel();
    _downloadCount.dispose();
    _settingsPanelOpen.dispose();
    _destination.dispose();
    super.dispose();
  }

  void _select(AppDestination destination) {
    _settingsPanelOpen.value = false;
    _destination.value = destination;
  }

  void _openFullSettings() {
    _settingsPanelOpen.value = false;
    _destination.value = AppDestination.settings;
  }

  void _showHelp() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        title: const Text('Video Pro Max'),
        content: const Text(
          'Windows 桌面端视频客户端\n当前版本：0.2.0\n视频来源：哔哩哔哩',
          style: TextStyle(fontSize: 12, height: 1.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 壁纸铺满整个窗口，页面底板保持透明，卡片与播放器仍是
    // 不透明深色底板 —— 正文始终落在高对比表面上。
    return ValueListenableBuilder<bool>(
      valueListenable: _settingsPanelOpen,
      builder: (context, panelOpen, _) {
        return ValueListenableBuilder<WallpaperState>(
          valueListenable: WallpaperSettings.instance.state,
          builder: (context, wallpaper, _) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: WallpaperBackground(
                state: wallpaper,
                isDay: wallpaper.isDayAt(DateTime.now()),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        _Sidebar(
                          destination: _destination,
                          downloadCount: _downloadCount,
                          onSelect: _select,
                          onSettings: () =>
                              _settingsPanelOpen.value = !panelOpen,
                          onHelp: _showHelp,
                        ),
                        Expanded(
                          child: IndexedStack(
                            index: _destination.value == AppDestination.settings
                                ? 1
                                : 0,
                            children: [
                              HomePage(
                                destination: _destination,
                                prefs: _prefs,
                                onDownloadCountChanged: (count) =>
                                    _downloadCount.value = count,
                              ),
                              SettingsPage(
                                prefs: _prefs,
                                onBack: () =>
                                    _destination.value = AppDestination.home,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (panelOpen) ...[
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _settingsPanelOpen.value = false,
                        ),
                      ),
                      Positioned(
                        left: 90,
                        top: 100,
                        child: Focus(
                          autofocus: true,
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent &&
                                event.logicalKey ==
                                    LogicalKeyboardKey.escape) {
                              _settingsPanelOpen.value = false;
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: SizedBox(
                            width: 320,
                            height: 426,
                            child: WallpaperSettingsPanel(
                              prefs: _prefs,
                              onClose: () => _settingsPanelOpen.value = false,
                              onOpenFullSettings: _openFullSettings,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destination,
    required this.downloadCount,
    required this.onSelect,
    required this.onSettings,
    required this.onHelp,
  });

  final ValueListenable<AppDestination> destination;
  final ValueListenable<int> downloadCount;
  final ValueChanged<AppDestination> onSelect;
  final VoidCallback onSettings;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      color: Colors.transparent,
      child: ValueListenableBuilder<AppDestination>(
        valueListenable: destination,
        builder: (context, current, _) {
          return Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF5B8CFF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'VH',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              for (final item in const [
                (AppDestination.home, Icons.home_outlined),
                (AppDestination.history, Icons.history),
                (AppDestination.downloads, Icons.download_outlined),
                (AppDestination.space, Icons.people_outline),
              ])
                _NavItem(
                  destination: item.$1,
                  icon: item.$2,
                  selected: current == item.$1,
                  downloadCount: downloadCount,
                  onTap: () => onSelect(item.$1),
                ),
              const Spacer(),
              IconButton(
                tooltip: '设置',
                onPressed: onSettings,
                icon: const Icon(
                  Icons.settings_outlined,
                  size: 19,
                  color: Color(0xFF657086),
                ),
              ),
              IconButton(
                tooltip: '帮助',
                onPressed: onHelp,
                icon: const Icon(
                  Icons.help_outline,
                  size: 19,
                  color: Color(0xFF657086),
                ),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.icon,
    required this.selected,
    required this.downloadCount,
    required this.onTap,
  });

  final AppDestination destination;
  final IconData icon;
  final bool selected;
  final ValueListenable<int> downloadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 62,
          height: 54,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1B2A4A) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Stack(
            children: [
              if (selected)
                Positioned(
                  left: -8,
                  top: 14,
                  child: Container(
                    width: 3,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFF5B8CFF),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 19,
                      color: selected
                          ? const Color(0xFFB8CBFF)
                          : const Color(0xFF657086),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      destination.label,
                      style: TextStyle(
                        fontSize: 9,
                        color: selected
                            ? const Color(0xFFB8CBFF)
                            : const Color(0xFF657086),
                      ),
                    ),
                  ],
                ),
              ),
              if (destination == AppDestination.downloads)
                ValueListenableBuilder<int>(
                  valueListenable: downloadCount,
                  builder: (context, count, _) {
                    if (count <= 0) return const SizedBox.shrink();
                    return Positioned(
                      top: 6,
                      right: 9,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 15),
                        height: 15,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5B8CFF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 8,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
