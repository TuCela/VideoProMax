import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'danmaku_bridge.dart';
import 'fullscreen_window.dart';

/// 播放器控制栏（进度条下方那一排按钮）。
///
/// 返回 List<Widget> 而不是一个 Row，是因为 media_kit 的
/// `bottomButtonBar` 本身就是列表，自己包一层 Row 会打乱它的间距布局。
///
/// 倍速、播放状态、弹幕开关直接监听 [DanmakuBridge] 的 notifier，
/// 这样 media_kit 全屏路由里的按钮快照也能正常响应。
List<Widget> buildControlBarButtons({
  required Player player,
  required bool canPrev,
  required bool canNext,
  required VoidCallback onPrev,
  required VoidCallback onNext,
  required VoidCallback onOpenEpisodes,
  required VoidCallback onToggleDanmaku,
  required VoidCallback onSendDanmaku,
  required VoidCallback onDanmakuSettings,
  required bool pipMode,
  required VoidCallback onTogglePip,
  required VoidCallback onCycleRate,
  required int fitIndex,
  required ValueChanged<int> onFitChanged,
  required ValueListenable<bool> theaterMode,
  required VoidCallback onToggleTheater,
  required VoidCallback onGlobalFullscreen,
  required VoidCallback onFullscreen,
}) {
  Widget btn(
    IconData icon,
    String tip,
    VoidCallback? onTap, {
    bool active = false,
    Object? animKey,
  }) {
    final color = onTap == null
        ? const Color(0x66888888)
        : (active ? const Color(0xFF9FB0FF) : Colors.white);
    final iconWidget = Icon(
      icon,
      key: ValueKey(animKey ?? icon),
      size: 22,
      color: color,
    );
    return Tooltip(
      message: tip,
      child: IconButton(
        onPressed: onTap,
        icon: animKey != null
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: iconWidget,
              )
            : iconWidget,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        constraints: const BoxConstraints(),
        splashRadius: 20,
      ),
    );
  }

  // 左端是时间标签（已观看 / 总时长），随后是播放与内容操作，
  // 弹性间隔把视图类按钮推到右侧，最右仍是全屏。
  // media_kit 的控制栏是单行 Row：不换行、不滚动，窗口变窄只会 overflow，
  // 因此低于阈值时把 7 个低频按钮收回「更多」，保证核心按钮始终可见。
  return [
    Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;
          return Row(
            children: [
              _timeLabel(),
              const SizedBox(width: 6),
              if (!compact) ...[
                _verticalDivider(),
                const SizedBox(width: 2),
              ],
              btn(Icons.skip_previous, '上一集', canPrev ? onPrev : null),
              _animatedPlayButton(player),
              btn(Icons.skip_next, '下一集', canNext ? onNext : null),
              if (compact) ...[
                _animatedDanmakuButton(onToggleDanmaku),
                _moreButton(
                  fitIndex: fitIndex,
                  pipMode: pipMode,
                  onOpenEpisodes: onOpenEpisodes,
                  onFitChanged: onFitChanged,
                  onSendDanmaku: onSendDanmaku,
                  onDanmakuSettings: onDanmakuSettings,
                  onTogglePip: onTogglePip,
                  onToggleTheater: onToggleTheater,
                  onGlobalFullscreen: onGlobalFullscreen,
                ),
              ] else ...[
                btn(Icons.queue_music, '选集', onOpenEpisodes),
                _fitButton(fitIndex, onFitChanged),
                _animatedDanmakuButton(onToggleDanmaku),
                btn(Icons.send, '发送弹幕', onSendDanmaku),
                btn(Icons.tune, '弹幕设置', onDanmakuSettings),
              ],
              const Spacer(),
              VolumeButton(
                player: player,
                volume: DanmakuBridge.instance.volume,
              ),
              _controlRateButton(onCycleRate),
              if (!compact) ...[
                btn(
                  Icons.picture_in_picture_alt,
                  '画中画',
                  onTogglePip,
                  active: pipMode,
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: GlobalFullscreen.stateNotifier,
                  builder: (_, active, __) => btn(
                    active ? Icons.fullscreen_exit : Icons.desktop_windows,
                    active ? '退出软件全屏' : '软件全屏',
                    onGlobalFullscreen,
                    active: active,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: theaterMode,
                  builder: (_, active, __) => btn(
                    active ? Icons.aspect_ratio : Icons.crop_landscape,
                    active ? '退出铺满' : '视频铺满窗口',
                    onToggleTheater,
                    active: active,
                  ),
                ),
              ],
              btn(Icons.fullscreen, '全屏播放', onFullscreen),
            ],
          );
        },
      ),
    ),
  ];
}

/// 用控制栏按钮构建播放器控制主题。
MaterialDesktopVideoControlsThemeData playerControlTheme(List<Widget> buttons) {
  return kDefaultMaterialDesktopVideoControlsThemeData.copyWith(
    // 进入全屏/铺满时立即显示控制栏，否则默认 false 要等鼠标移动才出现。
    visibleOnMount: true,
    // 单击视频画面切换播放/暂停（media_kit 内置，排除底部进度条区域）。
    playAndPauseOnTap: true,
    // 双击视频画面任意位置进入全屏播放。
    // media_kit 的实现是在 onTapUp 里比较两次点击的间隔，
    // 双击时 onTapDown 触发的两次播放/暂停切换会互相抵消，不冲突。
    toggleFullscreenOnDoublePress: true,
    // 滚轮音量由外层 Listener 统一处理（含阻止窗口模式 ScrollView 滚动），
    // 关闭 media_kit 内置避免重复调节。
    modifyVolumeOnScroll: false,
    bottomButtonBar: buttons,
    bottomButtonBarMargin: const EdgeInsets.symmetric(horizontal: 8),
    buttonBarHeight: 40,
    buttonBarButtonSize: 22,
    buttonBarButtonColor: Colors.white,
    controlsHoverDuration: const Duration(seconds: 4),
    seekBarColor: const Color(0x66FFFFFF),
    seekBarPositionColor: const Color(0xFF7C93FF),
    seekBarBufferColor: const Color(0x44FFFFFF),
    seekBarThumbColor: const Color(0xFF7C93FF),
  );
}

/// 由全局状态驱动、带图标切换动效的控制栏按钮。
Widget _statefulAnimButton(
  ValueListenable<bool> notifier,
  IconData iconOn,
  IconData iconOff,
  String tipOn,
  String tipOff,
  VoidCallback onTap, {
  bool highlight = false,
}) {
  return ValueListenableBuilder<bool>(
    valueListenable: notifier,
    builder: (_, on, __) {
      final icon = on ? iconOn : iconOff;
      final color = highlight && on ? const Color(0xFF9FB0FF) : Colors.white;
      return Tooltip(
        message: on ? tipOn : tipOff,
        child: IconButton(
          onPressed: onTap,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Icon(icon, key: ValueKey(icon), size: 22, color: color),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          constraints: const BoxConstraints(),
          splashRadius: 20,
        ),
      );
    },
  );
}

Widget _animatedPlayButton(Player player) {
  return _statefulAnimButton(
    DanmakuBridge.instance.playing,
    Icons.pause,
    Icons.play_arrow,
    '暂停',
    '播放',
    () => player.playOrPause(),
  );
}

Widget _animatedDanmakuButton(VoidCallback onToggle) {
  return _statefulAnimButton(
    DanmakuBridge.instance.danmakuOn,
    Icons.subtitles,
    Icons.subtitles_off,
    '弹幕开',
    '弹幕关',
    onToggle,
  );
}

/// 控制栏左端的「已观看 / 总时长」标签。
///
/// 直接监听 DanmakuBridge 而不是读 home_page 的 state：软件内全屏拿的是
/// 控制栏主题快照，home_page 的 setState 进不去，只有 notifier 能持续刷新。
Widget _timeLabel() {
  return ValueListenableBuilder<Duration>(
    valueListenable: DanmakuBridge.instance.position,
    builder: (_, pos, __) => ValueListenableBuilder<Duration>(
      valueListenable: DanmakuBridge.instance.duration,
      builder: (_, total, __) => Tooltip(
        message: '已观看 ${_fmtDuration(pos)} / 总时长 ${_fmtDuration(total)}',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 84),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _fmtDuration(pos),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEDF0F7),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Text(
                ' / ',
                style: TextStyle(fontSize: 12, color: Color(0xFF657086)),
              ),
              Text(
                total > Duration.zero ? _fmtDuration(total) : '--:--',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF929BAD),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 控制栏时长文案：不足 1 小时用 mm:ss，超过用 h:mm:ss。
String _fmtDuration(Duration value) {
  final seconds = value.inSeconds;
  if (seconds <= 0) return '00:00';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final rest = seconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = rest.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// 时间标签与按钮之间的细分隔线。
Widget _verticalDivider() {
  return Container(width: 1, height: 16, color: const Color(0x33FFFFFF));
}

/// 画面比例（适应 / 裁剪 / 拉伸），恢复旧版的独立按钮。
Widget _fitButton(int fitIndex, ValueChanged<int> onSelected) {
  return SizedBox(
    width: 34,
    height: 34,
    child: PopupMenuButton<int>(
      tooltip: '画面比例',
      color: const Color(0xFF171A20),
      padding: EdgeInsets.zero,
      iconSize: 22,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final entry in const [(0, '适应'), (1, '裁剪'), (2, '拉伸')])
          PopupMenuItem<int>(
            value: entry.$1,
            child: Text(
              '${entry.$2}${entry.$1 == fitIndex ? '  ✓' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
      icon: const Icon(Icons.aspect_ratio, size: 22, color: Colors.white),
    ),
  );
}

/// 窄窗口下的「更多」：收纳 7 个低频按钮，避免单行控制栏 overflow。
Widget _moreButton({
  required int fitIndex,
  required bool pipMode,
  required VoidCallback onOpenEpisodes,
  required ValueChanged<int> onFitChanged,
  required VoidCallback onSendDanmaku,
  required VoidCallback onDanmakuSettings,
  required VoidCallback onTogglePip,
  required VoidCallback onToggleTheater,
  required VoidCallback onGlobalFullscreen,
}) {
  return SizedBox(
    width: 34,
    height: 34,
    child: PopupMenuButton<int>(
      tooltip: '更多播放操作',
      color: const Color(0xFF171A20),
      padding: EdgeInsets.zero,
      iconSize: 22,
      onSelected: (value) {
        switch (value) {
          case 0:
            onOpenEpisodes();
          case 10:
            onFitChanged(0);
          case 11:
            onFitChanged(1);
          case 12:
            onFitChanged(2);
          case 20:
            onSendDanmaku();
          case 21:
            onDanmakuSettings();
          case 30:
            onTogglePip();
          case 31:
            onToggleTheater();
          case 32:
            onGlobalFullscreen();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem<int>(
          value: 0,
          child: Text('选集', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuDivider(),
        for (final entry in const [(10, '适应'), (11, '裁剪'), (12, '拉伸')])
          PopupMenuItem<int>(
            value: entry.$1,
            child: Text(
              '${entry.$2}${entry.$1 - 10 == fitIndex ? '  ✓' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<int>(
          value: 20,
          child: Text('发送弹幕', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<int>(
          value: 21,
          child: Text('弹幕设置', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<int>(
          value: 30,
          child: Text(
            pipMode ? '退出画中画' : '画中画',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const PopupMenuItem<int>(
          value: 31,
          child: Text('视频铺满窗口', style: TextStyle(fontSize: 12)),
        ),
        const PopupMenuItem<int>(
          value: 32,
          child: Text('软件全屏', style: TextStyle(fontSize: 12)),
        ),
      ],
      icon: const Icon(Icons.more_horiz, size: 22, color: Colors.white),
    ),
  );
}

/// 控制栏倍速按钮：显示当前档位，点击循环切换。
Widget _controlRateButton(VoidCallback onCycle) {
  return ValueListenableBuilder<double>(
    valueListenable: DanmakuBridge.instance.rate,
    builder: (_, rate, __) {
      final active = rate != 1.0;
      final color = active ? const Color(0xFF9FB0FF) : Colors.white;
      return Tooltip(
        message: '播放倍速（当前 ${rate}x，点击切换）',
        child: TextButton(
          onPressed: onCycle,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 7),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Text(
              '${rate}x',
              key: ValueKey(rate),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ),
      );
    },
  );
}
