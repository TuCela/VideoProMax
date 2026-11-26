// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderStack;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../bili/models.dart';
import 'danmaku_layer.dart';

/// 弹幕的静态配置（不含实时进度/播放态）。
class DanmakuConfig {
  const DanmakuConfig({
    required this.items,
    required this.cid,
    required this.enabled,
    required this.opacity,
    required this.fontScale,
    required this.speed,
    required this.area,
  });

  final List<DanmakuItem> items;
  final String cid;
  final bool enabled;
  final double opacity;
  final double fontScale;
  final double speed;
  final double area;

  bool sameAs(DanmakuConfig? other) =>
      other != null &&
      identical(other.items, items) &&
      other.cid == cid &&
      other.enabled == enabled &&
      other.opacity == opacity &&
      other.fontScale == fontScale &&
      other.speed == speed &&
      other.area == area;
}

/// 控制栏内「选集」浮层的一条数据。
/// home_page 在 build 时把当前分P/剧集推给桥接层，
/// 全屏路由里的浮层直接读它，不受控制栏主题快照影响。
class EpisodeEntry {
  const EpisodeEntry({
    required this.label,
    required this.title,
    required this.meta,
    required this.playing,
    required this.onTap,
  });

  final String label;
  final String title;
  final String meta;
  final bool playing;
  final VoidCallback onTap;
}

/// 桥接 HomePage 与自定义 Video controls builder。
///
/// media_kit 的软件内全屏会 push 一个新路由、重建 Video，
/// 外部 Stack 里的弹幕层会丢失。把弹幕层放进 controls builder
/// 后，窗口与全屏的 Video 都用同一套 builder，弹幕即可常驻。
class DanmakuBridge {
  DanmakuBridge._();

  static final DanmakuBridge instance = DanmakuBridge._();

  final ValueNotifier<DanmakuConfig?> config = ValueNotifier<DanmakuConfig?>(null);

  /// 播放/暂停状态与弹幕开关：控制栏按钮直接监听它们做动效。
  /// media_kit 全屏路由持有的是控制栏主题快照，home_page 的 setState
  /// 传不进去，因此这两个状态必须由全局 notifier 驱动。
  final ValueNotifier<bool> playing = ValueNotifier<bool>(false);
  final ValueNotifier<bool> danmakuOn = ValueNotifier<bool>(true);

  /// 播放倍速：控制栏倍速按钮监听它显示当前档位。
  final ValueNotifier<double> rate = ValueNotifier<double>(1.0);

  /// 已观看进度与视频总时长：控制栏左端时间标签监听它们。
  /// 与播放状态同理，全屏路由拿的是控制栏主题快照，必须由 notifier 驱动
  /// 才能在软件内全屏里持续刷新。按秒取整，避免每帧重建控制栏。
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration> duration = ValueNotifier<Duration>(
    Duration.zero,
  );

  /// 同步播放进度与总时长，秒级去重后再通知监听者。
  void updatePlaybackTime(Duration pos, Duration total) {
    final nextPos = Duration(seconds: pos.inSeconds);
    final nextTotal = Duration(seconds: total.inSeconds);
    if (position.value != nextPos) position.value = nextPos;
    if (duration.value != nextTotal) duration.value = nextTotal;
  }

  /// 选集浮层：显隐由全局 notifier 驱动，窗口/全屏控制栏都能打开。
  final ValueNotifier<bool> episodePanelVisible = ValueNotifier<bool>(false);
  final ValueNotifier<int> episodeRevision = ValueNotifier<int>(0);
  List<EpisodeEntry> episodes = const [];
  String episodeSummary = '';
  bool episodeHasTabs = false;
  bool episodeSeasonTab = false;
  bool episodeDesc = false;
  VoidCallback? onToggleEpisodeTab;
  VoidCallback? onToggleEpisodeDesc;
  String _episodeKey = '';

  /// 音量：控制栏音量按钮监听它显示图标/滑块；滚轮调节时也更新它。
  final ValueNotifier<double> volume = ValueNotifier<double>(100.0);

  /// 音量面板显隐（面板放在 controls 的 Stack 里，用测量坐标定位）。
  final ValueNotifier<bool> volumePanelVisible = ValueNotifier<bool>(false);
  /// 音量按钮在各自 controls Stack 中的中心坐标（hover 时测量）。
  /// 不再用 LayerLink 跟随按钮：控制栏自动隐藏会卸载按钮(target)，
  /// 导致 follower 断链、面板闪现闪隐。测量坐标则稳定不跳变。
  /// 注意：窗口/全屏各有独立 Video，坐标由各自的按钮 context 测量，
  /// 通过 isFullscreen 标志区分，避免共用同一 notifier 导致串位。
  final ValueNotifier<Offset?> volumeButtonPos = ValueNotifier<Offset?>(null);
  double lastVolume = 100.0;
  Timer? _volumePanelTimer;
  // 光标是否停留在按钮或面板上。定时器触发时据此判断是否真的离开了，
  // 避免光标停在面板上时因为边界 event 抖动导致面板反复显隐（闪烁）。
  bool _volumeButtonHovered = false;
  bool _volumePanelHovered = false;

  void onVolumeButtonEnter() {
    _volumeButtonHovered = true;
    showVolumePanel();
  }

  void onVolumeButtonExit() {
    _volumeButtonHovered = false;
    hideVolumePanelDelayed();
  }

  void onVolumePanelEnter() {
    _volumePanelHovered = true;
    showVolumePanel();
  }

  void onVolumePanelExit() {
    _volumePanelHovered = false;
    hideVolumePanelDelayed();
  }

  void showVolumePanel() {
    _volumePanelTimer?.cancel();
    _volumePanelTimer = null;
    volumePanelVisible.value = true;
  }

  void hideVolumePanelDelayed() {
    _volumePanelTimer?.cancel();
    _volumePanelTimer = Timer(const Duration(seconds: 1), () {
      // 光标仍在按钮或面板上 → 不隐藏，重新等待。
      if (_volumeButtonHovered || _volumePanelHovered) {
        hideVolumePanelDelayed();
        return;
      }
      volumePanelVisible.value = false;
    });
  }

  /// 当前 VideoState（供全屏按钮调用 enter/exitFullscreen）。
  VideoState? videoState;

  Player? player;

  void update({
    required List<DanmakuItem> items,
    required String cid,
    required bool enabled,
    required double opacity,
    required double fontScale,
    required double speed,
    required double area,
  }) {
    final next = DanmakuConfig(
      items: items,
      cid: cid,
      enabled: enabled,
      opacity: opacity,
      fontScale: fontScale,
      speed: speed,
      area: area,
    );
    if (!next.sameAs(config.value)) config.value = next;
  }

  /// home_page 每次构建时同步选集数据；内容没变化时不动 notifier，
  /// 避免播放进度频繁 setState 导致全屏浮层反复重建。
  void updateEpisodes({
    required String key,
    required List<EpisodeEntry> entries,
    required String summary,
    required bool hasTabs,
    required bool seasonTab,
    required bool desc,
    required VoidCallback onToggleTab,
    required VoidCallback onToggleDesc,
  }) {
    if (key == _episodeKey) return;
    _episodeKey = key;
    episodes = entries;
    episodeSummary = summary;
    episodeHasTabs = hasTabs;
    episodeSeasonTab = seasonTab;
    episodeDesc = desc;
    onToggleEpisodeTab = onToggleTab;
    onToggleEpisodeDesc = onToggleDesc;
    episodeRevision.value++;
  }
}

/// 自己订阅播放进度与播放态，只重建弹幕层，不干扰控制栏。
class BridgedDanmakuLayer extends StatefulWidget {
  const BridgedDanmakuLayer({
    super.key,
    required this.player,
    required this.config,
  });

  final Player player;
  final DanmakuConfig config;

  @override
  State<BridgedDanmakuLayer> createState() => _BridgedDanmakuLayerState();
}

class _BridgedDanmakuLayerState extends State<BridgedDanmakuLayer> {
  Duration _position = Duration.zero;
  bool _playing = false;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playSub;

  @override
  void initState() {
    super.initState();
    _posSub = widget.player.stream.position.listen((value) {
      if (mounted) setState(() => _position = value);
    });
    _playSub = widget.player.stream.playing.listen((value) {
      if (mounted) setState(() => _playing = value);
    });
  }

  @override
  void didUpdateWidget(covariant BridgedDanmakuLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) {
      _posSub?.cancel();
      _playSub?.cancel();
      _posSub = widget.player.stream.position.listen((value) {
        if (mounted) setState(() => _position = value);
      });
      _playSub = widget.player.stream.playing.listen((value) {
        if (mounted) setState(() => _playing = value);
      });
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _playSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    if (!cfg.enabled || cfg.items.isEmpty) {
      return const SizedBox.shrink();
    }
    return DanmakuLayer(
      key: ValueKey(cfg.cid),
      items: cfg.items,
      position: _position,
      playing: _playing,
      enabled: cfg.enabled,
      opacity: cfg.opacity,
      fontScale: cfg.fontScale,
      speed: cfg.speed,
      area: cfg.area,
    );
  }
}

/// 自定义 Video controls：弹幕层 + media_kit 桌面控制栏。
///
/// 作为 [Video.controls] 传入，全屏路由里的 Video 会复用同一个 builder。
Widget hubVideoControls(VideoState state) {
  final bridge = DanmakuBridge.instance;
  bridge.videoState = state;
  return Listener(
    // 光标在视频区域内滚轮调节音量。视频区已移出页面的 ScrollView，
    // 滚轮不会被页面滚动抢走。
    onPointerSignal: (event) {
      if (event is PointerScrollEvent && bridge.player != null) {
        final delta = event.scrollDelta.dy;
        if (delta != 0) {
          final current = bridge.player!.state.volume;
          final next = (current + (delta < 0 ? 5.0 : -5.0)).clamp(0.0, 100.0);
          bridge.player!.setVolume(next);
          bridge.volume.value = next;
        }
      }
    },
    child: Stack(
    fit: StackFit.expand,
    children: [
      ValueListenableBuilder<DanmakuConfig?>(
        valueListenable: bridge.config,
        builder: (_, cfg, __) {
          if (cfg == null || bridge.player == null) {
            return const SizedBox.shrink();
          }
          return Positioned.fill(
            child: BridgedDanmakuLayer(player: bridge.player!, config: cfg),
          );
        },
      ),
      MaterialDesktopVideoControls(state),
      // B站风格音量面板：放在 controls 的 Stack（视频尺寸）内，
      // 而非全屏 Overlay，避免拿到全屏约束被撑大。
      // 面板用 hover 时测得的按钮坐标定位（固定 Positioned），
      // 不再用 CompositedTransformFollower 跟随按钮 —— 后者在控制栏
      // 自动隐藏、卸载按钮(target) 时会断链，导致面板闪烁。
      ValueListenableBuilder<Offset?>(
        valueListenable: bridge.volumeButtonPos,
        builder: (_, pos, __) {
          if (bridge.player == null || pos == null) {
            return const SizedBox.shrink();
          }
          return ValueListenableBuilder<bool>(
            valueListenable: bridge.volumePanelVisible,
            builder: (_, visible, __) {
              // 面板宽 46、高约 132；居中对齐按钮、底边距按钮顶部 10。
              final left = pos.dx - 23;
              final top = pos.dy - 132 - 10;
              return Positioned(
                left: left,
                top: top,
                child: MouseRegion(
                  onEnter: (_) => bridge.onVolumePanelEnter(),
                  onExit: (_) => bridge.onVolumePanelExit(),
                  child: IgnorePointer(
                    ignoring: !visible,
                    child: AnimatedOpacity(
                      opacity: visible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 120),
                      child: VolumePanel(
                        player: bridge.player!,
                        volume: bridge.volume,
                        onVolumeChanged: (v) {
                          if (v > 0) bridge.lastVolume = v;
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      // 选集浮层：窗口与软件内全屏共用同一份桥接数据，
      // 放在 controls 的 Stack 内，点击选集按钮即在视频窗口内弹出。
      ValueListenableBuilder<bool>(
        valueListenable: bridge.episodePanelVisible,
        builder: (_, visible, __) {
          if (!visible) return const SizedBox.shrink();
          return Positioned(
            right: 10,
            top: 10,
            bottom: 52,
            child: ValueListenableBuilder<int>(
              valueListenable: bridge.episodeRevision,
              builder: (_, ___, ____) => EpisodeOverlay(bridge: bridge),
            ),
          );
        },
      ),
    ],
    ),
  );
}

/// 视频窗口内的选集浮层（窗口/全屏通用）。
class EpisodeOverlay extends StatelessWidget {
  const EpisodeOverlay({super.key, required this.bridge});

  final DanmakuBridge bridge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 248,
      decoration: BoxDecoration(
        color: const Color(0xF0171A20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF3A3F48)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: Icon(Icons.video_library_outlined,
                    size: 15, color: Color(0xFF8B9099)),
              ),
              const SizedBox(width: 6),
              const Text('选集',
                  style: TextStyle(fontSize: 12, color: Color(0xFFE8EAED))),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  bridge.episodeSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF6E7480)),
                ),
              ),
              IconButton(
                tooltip: '关闭选集',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                icon: const Icon(Icons.close, color: Color(0xFFC9CDD4)),
                onPressed: () => bridge.episodePanelVisible.value = false,
              ),
            ],
          ),
          if (bridge.episodeHasTabs)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('分P', style: TextStyle(fontSize: 11)),
                    selected: !bridge.episodeSeasonTab,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => bridge.onToggleEpisodeTab?.call(),
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    label: const Text('合集', style: TextStyle(fontSize: 11)),
                    selected: bridge.episodeSeasonTab,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => bridge.onToggleEpisodeTab?.call(),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 26),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: bridge.episodeDesc
                      ? const Color(0xFF9FB0FF)
                      : const Color(0xFF8B9099),
                ),
                onPressed: () => bridge.onToggleEpisodeDesc?.call(),
                icon: const Icon(Icons.swap_vert, size: 13),
                label: Text(
                  bridge.episodeDesc ? '倒序' : '正序',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: bridge.episodes.length,
              itemBuilder: (_, index) {
                final entry = bridge.episodes[index];
                final color = entry.playing
                    ? const Color(0xFF9FB0FF)
                    : const Color(0xFFC9CDD4);
                return InkWell(
                  onTap: () {
                    bridge.episodePanelVisible.value = false;
                    entry.onTap();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    color: entry.playing
                        ? const Color(0xFF1E2533)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(entry.label,
                              style: TextStyle(fontSize: 10, color: color)),
                        ),
                        Expanded(
                          child: Text(
                            entry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: color),
                          ),
                        ),
                        if (entry.meta.isNotEmpty)
                          Text(entry.meta,
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF6E7480))),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 音量面板：百分比数字 + 竖直滑块。与第一版一致：宽 46、高约 132，
/// 由内容撑起尺寸，外层用 Positioned 给 loose 约束防止被撑满。
class VolumePanel extends StatelessWidget {
  const VolumePanel({
    super.key,
    required this.player,
    required this.volume,
    required this.onVolumeChanged,
  });

  final Player player;
  final ValueListenable<double> volume;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: volume,
      builder: (_, vol, __) {
        final int percent = vol.round();
        // 与第一版一致：宽 46，高度由内容撑起（约 132），不再撑满父级。
        return Container(
          width: 46,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xF0171A20),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9FB0FF),
                ),
              ),
              const SizedBox(height: 8),
              // RotatedBox 交换宽高：给 Slider 固定 96x36，
              // 旋转后显示为 36 宽、96 高的竖直滑块。
              SizedBox(
                width: 36,
                height: 96,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: SizedBox(
                    width: 96,
                    height: 36,
                    child: Slider(
                      value: vol.clamp(0.0, 100.0),
                      min: 0.0,
                      max: 100.0,
                      activeColor: const Color(0xFF9FB0FF),
                      inactiveColor: const Color(0x66FFFFFF),
                      onChanged: (value) {
                        onVolumeChanged(value);
                        player.setVolume(value);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// B站风格音量按钮。hover 时测量自身坐标存入 bridge，
/// 面板由 hubVideoControls 在该坐标上方绘制，可正常拖动滑块。
class VolumeButton extends StatefulWidget {
  const VolumeButton({super.key, required this.player, required this.volume});

  final Player player;
  final ValueListenable<double> volume;

  @override
  State<VolumeButton> createState() => _VolumeButtonState();
}

class _VolumeButtonState extends State<VolumeButton> {
  final GlobalKey _buttonKey = GlobalKey();

  /// 测量按钮相对各自 controls Stack 的中心坐标，存给面板定位。
  /// 向上查找最近的 RenderStack（即 hubVideoControls 的根 Stack），
  /// 窗口与全屏各有独立 Stack，各自测量互不干扰。
  void _measureAndEnter() {
    final bridge = DanmakuBridge.instance;
    final btnCtx = _buttonKey.currentContext;
    if (btnCtx != null) {
      final btnBox = btnCtx.findRenderObject() as RenderBox?;
      final stackBox = btnCtx.findAncestorRenderObjectOfType<RenderStack>();
      if (btnBox != null && stackBox != null && btnBox.hasSize) {
        final center = btnBox.localToGlobal(btnBox.size.center(Offset.zero));
        bridge.volumeButtonPos.value = stackBox.globalToLocal(center);
      }
    }
    bridge.onVolumeButtonEnter();
  }

  @override
  Widget build(BuildContext context) {
    final bridge = DanmakuBridge.instance;
    return ValueListenableBuilder<double>(
      valueListenable: widget.volume,
      builder: (_, vol, __) {
        final IconData icon = vol <= 0
            ? Icons.volume_off
            : (vol < 50 ? Icons.volume_down : Icons.volume_up);
        return MouseRegion(
          onEnter: (_) => _measureAndEnter(),
          onExit: (_) => bridge.onVolumeButtonExit(),
          child: Tooltip(
            message: vol <= 0 ? '取消静音' : '静音',
            child: IconButton(
              key: _buttonKey,
              onPressed: () async {
                if (vol <= 0) {
                  await widget.player.setVolume(bridge.lastVolume);
                } else {
                  bridge.lastVolume = vol;
                  await widget.player.setVolume(0);
                }
              },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Icon(icon,
                    key: ValueKey(icon), size: 22, color: Colors.white),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
          ),
        );
      },
    );
  }
}
