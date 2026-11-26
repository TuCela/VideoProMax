// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter/material.dart';
import 'surface_settings.dart';

/// 视频下方的一排扁平工具栏（选集 / 画面比例 / 弹幕 / 画中画 / 下载）。
class PlayerToolbar extends StatelessWidget {
  const PlayerToolbar({
    super.key,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.onOpenEpisodes,
    required this.fitIndex,
    required this.onFitChanged,
    required this.danmakuOn,
    required this.onToggleDanmaku,
    required this.onSendDanmaku,
    required this.onDanmakuSettings,
    required this.pipMode,
    required this.onTogglePip,
    required this.onDownload,
  });

  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onOpenEpisodes;

  final int fitIndex;
  final ValueChanged<int> onFitChanged;

  final bool danmakuOn;
  final VoidCallback onToggleDanmaku;
  final VoidCallback onSendDanmaku;
  final VoidCallback onDanmakuSettings;

  final bool pipMode;
  final VoidCallback onTogglePip;
  final VoidCallback onDownload;

  Widget _button(
    IconData icon,
    String label,
    VoidCallback? onTap, {
    bool active = false,
  }) {
    final color = onTap == null
        ? const Color(0xFF4A4F58)
        : (active ? const Color(0xFF7C93FF) : const Color(0xFFC9CDD4));
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: color,
        backgroundColor: active
            ? Color(0xFF1B2A4A).withValues(alpha: 0.6)
            : SurfaceSettings.instance.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: BorderSide(
            color: active ? const Color(0xFF385A9F) : const Color(0xFF2A2E36),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  Widget _fitMenu() {
    const labels = ['适应', '裁剪', '拉伸'];
    return PopupMenuButton<int>(
      tooltip: '画面比例',
      onSelected: onFitChanged,
      itemBuilder: (context) => [
        for (var i = 0; i < labels.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Text(
              '${labels[i]}${i == fitIndex ? '  ✓' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: SurfaceSettings.instance.color,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFF2A2E36)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.aspect_ratio, size: 15, color: Color(0xFFC9CDD4)),
            const SizedBox(width: 6),
            Text(
              labels[fitIndex],
              style: const TextStyle(fontSize: 10, color: Color(0xFFC9CDD4)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 12, color: Color(0xFF6E7480)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: SurfaceSettings.instance.color,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFF2A313E)),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _button(Icons.skip_previous, '上一集', canPrev ? onPrev : null),
          _button(Icons.skip_next, '下一集', canNext ? onNext : null),
          _button(Icons.queue_music, '选集', onOpenEpisodes),
          _fitMenu(),
          _button(
            danmakuOn ? Icons.subtitles : Icons.subtitles_off,
            danmakuOn ? '弹幕开' : '弹幕关',
            onToggleDanmaku,
            active: danmakuOn,
          ),
          _button(Icons.download, '下载视频', onDownload),
          PopupMenuButton<int>(
            tooltip: '更多播放操作',
            onSelected: (value) {
              switch (value) {
                case 0:
                  onSendDanmaku();
                case 1:
                  onDanmakuSettings();
                case 2:
                  onTogglePip();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem<int>(
                value: 0,
                child: Text('发送弹幕', style: TextStyle(fontSize: 12)),
              ),
              const PopupMenuItem<int>(
                value: 1,
                child: Text('弹幕设置', style: TextStyle(fontSize: 12)),
              ),
              PopupMenuItem<int>(
                value: 2,
                child: Text(
                  pipMode ? '退出画中画' : '画中画',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: SurfaceSettings.instance.color,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: const Color(0xFF2A2E36)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.more_horiz,
                    size: 15,
                    color: Color(0xFFC9CDD4),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '更多',
                    style: TextStyle(fontSize: 10, color: Color(0xFFC9CDD4)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 视频下方的 UP 主信息：头像 + 名字，点击进入对应 UP 空间首页。
class UploaderChip extends StatelessWidget {
  const UploaderChip({
    super.key,
    required this.author,
    required this.face,
    required this.onTap,
  });

  final String author;
  final String face;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: SurfaceSettings.instance.color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF2A2E36)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2A2E36),
                border: Border.all(color: const Color(0xFF7C93FF), width: 1.2),
                image: face.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(face),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: face.isEmpty
                  ? const Icon(Icons.person, size: 13, color: Color(0xFF8B9099))
                  : null,
            ),
            const SizedBox(width: 6),
            Text(
              author,
              style: const TextStyle(fontSize: 12, color: Color(0xFFC9CDD4)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 13, color: Color(0xFF7C93FF)),
          ],
        ),
      ),
    );
  }
}
