// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/window_chrome.dart';
import 'font_settings.dart';
import 'surface_settings.dart';

class HomeHeader extends StatefulWidget {
  const HomeHeader({
    super.key,
    required this.searchController,
    required this.searching,
    required this.onSearch,
    required this.loggedIn,
    required this.userName,
    required this.avatarUrl,
    required this.onLogin,
    required this.onLogout,
    required this.onFontChanged,
    required this.onSettings,
    required this.onUpSpace,
    required this.platform,
    required this.onPlatformChanged,
  });

  final TextEditingController searchController;
  final bool searching;
  final VoidCallback onSearch;
  final bool loggedIn;
  final String userName;
  final String avatarUrl;
  final VoidCallback onLogin;
  final VoidCallback onLogout;
  final VoidCallback onFontChanged;
  final VoidCallback onSettings;
  final VoidCallback onUpSpace;

  /// 当前视频源平台代码：bili / youtube / other。
  final String platform;
  final ValueChanged<String> onPlatformChanged;

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  final FocusNode _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _window(String method) => WindowChrome.invoke(method);

  void _changeFont(int action) {
    switch (action) {
      case -1:
        FontSettings.instance.decrease();
      case 0:
        FontSettings.instance.reset();
      case 1:
        FontSettings.instance.increase();
    }
    widget.onFontChanged();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _searchFocus.requestFocus(),
      },
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: const BoxDecoration(color: Colors.transparent),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1180;
            return GestureDetector(
              // 顶部栏任意空白处：按住就能拖动窗口，双击最大化。
              // translucent 让搜索框、按钮等子控件优先拿到点击，
              // 只有空白处的拖动才落到这层。
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => _window('drag'),
              onDoubleTap: () => _window('maximize'),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => _window('drag'),
                    onDoubleTap: () => _window('maximize'),
                    child: Container(
                      width: compact ? 132 : 236,
                      height: 64,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Video Pro Max',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!compact) ...[
                            const SizedBox(width: 10),
                            _PlatformButton(
                              platform: widget.platform,
                              onChanged: widget.onPlatformChanged,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 660),
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: SurfaceSettings.instance.color,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: Color(0xFF2A313E)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search,
                                size: 16,
                                color: Color(0xFF657086),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: TextField(
                                  controller: widget.searchController,
                                  focusNode: _searchFocus,
                                  onSubmitted: (_) => widget.onSearch(),
                                  style: const TextStyle(fontSize: 11),
                                  decoration: const InputDecoration(
                                    hintText: '搜索视频、UP 主或 BV 号',
                                    hintStyle: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF657086),
                                    ),
                                    isDense: true,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 9,
                                    ),
                                  ),
                                ),
                              ),
                              if (!compact) ...[
                                const SizedBox(width: 7),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Color(0xFF2A313E)),
                                  ),
                                  child: const Text(
                                    'Ctrl K',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Color(0xFF657086),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 7),
                              SizedBox(
                                height: 28,
                                child: FilledButton(
                                  onPressed: widget.searching
                                      ? null
                                      : widget.onSearch,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: Text(
                                    widget.searching ? '搜索中' : '搜索',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RoundFontButton(
                    tooltip: '减小字号',
                    icon: Icons.remove,
                    onPressed: () => _changeFont(-1),
                  ),
                  const SizedBox(width: 6),
                  _FontMenu(
                    onChanged: widget.onFontChanged,
                    onChangeFont: _changeFont,
                  ),
                  const SizedBox(width: 6),
                  _RoundFontButton(
                    tooltip: '增大字号',
                    icon: Icons.add,
                    onPressed: () => _changeFont(1),
                  ),
                  Container(
                    width: 1,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: Color(0xFF2A313E),
                  ),
                  _UserMenu(
                    loggedIn: widget.loggedIn,
                    name: widget.userName,
                    avatar: widget.avatarUrl,
                    compact: compact,
                    onUpSpace: widget.onUpSpace,
                    onSettings: widget.onSettings,
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      onPressed: widget.loggedIn
                          ? widget.onLogout
                          : widget.onLogin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Color(0xFFC9CDD4),
                        side: const BorderSide(color: Color(0xFF2A313E)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      child: Text(
                        widget.loggedIn ? '退出' : '扫码登录',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _WindowControls(onInvoke: _window),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PlatformButton extends StatelessWidget {
  const _PlatformButton({required this.platform, required this.onChanged});

  final String platform;
  final ValueChanged<String> onChanged;

  static const Map<String, String> _labels = {
    'bili': '哔哩哔哩',
    'youtube': 'YouTube',
    'other': '其他平台',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '切换视频源平台',
      color: SurfaceSettings.instance.color,
      padding: EdgeInsets.zero,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final entry in _labels.entries)
          PopupMenuItem<String>(
            value: entry.key,
            child: Row(
              children: [
                Icon(
                  entry.key == platform
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 14,
                  color: entry.key == platform
                      ? const Color(0xFF5B8CFF)
                      : const Color(0xFF657086),
                ),
                const SizedBox(width: 8),
                Text(entry.value, style: const TextStyle(fontSize: 12)),
                if (entry.key != 'bili') ...[
                  const SizedBox(width: 8),
                  const Text(
                    '即将接入',
                    style: TextStyle(fontSize: 9, color: Color(0xFF657086)),
                  ),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: SurfaceSettings.instance.color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2A313E)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              platform,
              style: const TextStyle(fontSize: 9, color: Color(0xFF929BAD)),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.expand_more, size: 11, color: Color(0xFF657086)),
          ],
        ),
      ),
    );
  }
}

class _RoundFontButton extends StatelessWidget {
  const _RoundFontButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 26, height: 26),
        style: IconButton.styleFrom(
          backgroundColor: SurfaceSettings.instance.color,
          shape: const CircleBorder(side: BorderSide(color: Color(0xFF2A313E))),
        ),
        icon: Icon(icon, size: 13, color: const Color(0xFF929BAD)),
      ),
    );
  }
}

class _FontMenu extends StatelessWidget {
  const _FontMenu({required this.onChanged, required this.onChangeFont});

  final VoidCallback onChanged;
  final ValueChanged<int> onChangeFont;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: FontSettings.instance.delta,
      builder: (context, delta, _) {
        return PopupMenuButton<int>(
          tooltip: '全局字号',
          color: SurfaceSettings.instance.color,
          onSelected: (value) {
            onChangeFont(value);
            onChanged();
          },
          itemBuilder: (_) => [
            PopupMenuItem<int>(
              value: -1,
              enabled: delta > -4,
              child: const Text('缩小字体', style: TextStyle(fontSize: 12)),
            ),
            PopupMenuItem<int>(
              value: 0,
              child: const Text('重置为 14px', style: TextStyle(fontSize: 12)),
            ),
            PopupMenuItem<int>(
              value: 1,
              enabled: delta < 12,
              child: const Text('放大字体', style: TextStyle(fontSize: 12)),
            ),
          ],
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: SurfaceSettings.instance.color,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: Color(0xFF2A313E)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.text_fields,
                  size: 15,
                  color: Color(0xFF929BAD),
                ),
                const SizedBox(width: 6),
                Text(
                  '${14 + delta}px',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF929BAD),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserMenu extends StatelessWidget {
  const _UserMenu({
    required this.loggedIn,
    required this.name,
    required this.avatar,
    required this.compact,
    required this.onUpSpace,
    required this.onSettings,
  });

  final bool loggedIn;
  final String name;
  final String avatar;
  final bool compact;
  final VoidCallback onUpSpace;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final displayName = loggedIn ? (name.isEmpty ? '已登录' : name) : '未登录';
    return PopupMenuButton<String>(
      tooltip: '账号菜单',
      color: SurfaceSettings.instance.color,
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'space') onUpSpace();
        if (value == 'settings') onSettings();
      },
      itemBuilder: (_) => [
        if (loggedIn)
          const PopupMenuItem<String>(
            value: 'space',
            child: Text('UP 空间', style: TextStyle(fontSize: 12)),
          ),
        const PopupMenuItem<String>(
          value: 'settings',
          child: Text('设置', style: TextStyle(fontSize: 12)),
        ),
      ],
      child: SizedBox(
        height: 38,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF273149),
                border: Border.all(
                  color: loggedIn
                      ? const Color(0xFF5B8CFF)
                      : const Color(0xFF3A3F48),
                  width: 1.4,
                ),
                image: loggedIn && avatar.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(avatar),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: loggedIn && avatar.isEmpty
                  ? const Icon(Icons.person, size: 15, color: Color(0xFFB8CBFF))
                  : null,
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: loggedIn ? FontWeight.w600 : FontWeight.normal,
                  color: loggedIn
                      ? const Color(0xFFEDF0F7)
                      : const Color(0xFF929BAD),
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 13, color: Color(0xFF657086)),
          ],
        ),
      ),
    );
  }
}

class _WindowControls extends StatelessWidget {
  const _WindowControls({required this.onInvoke});

  final Future<void> Function(String) onInvoke;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          icon: Icons.remove,
          tooltip: '最小化',
          onPressed: () => onInvoke('minimize'),
        ),
        _WindowButton(
          icon: Icons.crop_square,
          tooltip: '最大化 / 还原',
          onPressed: () => onInvoke('maximize'),
        ),
        _WindowButton(
          icon: Icons.close,
          tooltip: '关闭',
          danger: true,
          onPressed: () => onInvoke('close'),
        ),
      ],
    );
  }
}

class _WindowButton extends StatelessWidget {
  const _WindowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        icon: Icon(
          icon,
          size: 15,
          color: danger ? const Color(0xFF929BAD) : const Color(0xFF657086),
        ),
      ),
    );
  }
}
