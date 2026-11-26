import 'package:flutter/material.dart';

import 'danmaku_bridge.dart';

/// 选集面板：分 P / 合集 / 版权剧集共用一套列表。
///
/// [sidebar] 为 true 时放在播放器右侧常驻；收起态压成一条 38px 宽的竖条，
/// 只显示图标和条目数，把宽度让给播放器。
class EpisodePanel extends StatelessWidget {
  const EpisodePanel({
    super.key,
    required this.entries,
    required this.summary,
    required this.hasTabs,
    required this.seasonTab,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onToggleSeasonTab,
    this.sidebar = false,
  });

  final List<EpisodeEntry> entries;
  final String summary;

  /// 同时存在分 P 和合集时才显示切换 tab。
  final bool hasTabs;

  /// 当前是否选中「合集」tab。
  final bool seasonTab;

  /// 列表是否展开。
  final bool expanded;

  final VoidCallback onToggleExpanded;

  /// 在「分P」和「合集」之间切换。
  final VoidCallback onToggleSeasonTab;

  final bool sidebar;

  Widget _tile(EpisodeEntry entry) {
    final color =
        entry.playing ? const Color(0xFF7C93FF) : const Color(0xFFC9CDD4);
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: entry.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: entry.playing ? const Color(0xFF1E2533) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              child: Text(entry.label,
                  style: TextStyle(fontSize: 11, color: color)),
            ),
            Expanded(
              child: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: color),
              ),
            ),
            if (entry.meta.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  entry.meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF6E7480)),
                ),
              ),
            ],
            if (entry.playing) ...[
              const SizedBox(width: 6),
              const Icon(Icons.volume_up,
                  size: 13, color: Color(0xFF7C93FF)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _list() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: entries.length,
      itemBuilder: (_, index) => _tile(entries[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 收起态压成一条 38px 宽的竖条：图标 + 数量，不给播放器占地方。
    if (sidebar && !expanded) {
      return Center(
        child: Tooltip(
          message: '展开选集（共 ${entries.length} 个）',
          child: InkWell(
            onTap: onToggleExpanded,
            borderRadius: BorderRadius.circular(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.video_library_outlined,
                    size: 18, color: Color(0xFF9FB0FF)),
                const SizedBox(height: 2),
                Text(
                  '${entries.length}',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF8B9099)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: sidebar ? EdgeInsets.zero : const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF14171C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF23262D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.video_library_outlined,
                  size: 15, color: Color(0xFF8B9099)),
              const SizedBox(width: 6),
              const Text('选集',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8B9099))),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF6E7480)),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onToggleExpanded,
                child: Text(
                  expanded ? '收起' : '展开',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
          if (hasTabs)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('分P', style: TextStyle(fontSize: 11)),
                    selected: !seasonTab,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => onToggleSeasonTab(),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('合集', style: TextStyle(fontSize: 11)),
                    selected: seasonTab,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => onToggleSeasonTab(),
                  ),
                ],
              ),
            ),
          if (expanded)
            sidebar
                ? Expanded(child: _list())
                : SizedBox(height: 208, child: _list()),
        ],
      ),
    );
  }
}
