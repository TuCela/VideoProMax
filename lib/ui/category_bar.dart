// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter/material.dart';
import 'surface_settings.dart';

/// 首页分区：rid 为普通分区 id；seasonType 非空表示版权分区（番剧 1 / 国创 4 / 综艺 7）。
class BiliCategory {
  const BiliCategory(this.name, this.rid, [this.seasonType]);

  final String name;
  final int rid;
  final int? seasonType;
}

const List<BiliCategory> kBiliCategories = [
  BiliCategory('番剧', 13, 1),
  BiliCategory('国创', 167, 4),
  BiliCategory('综艺', 71, 7),
  BiliCategory('动画', 1),
  BiliCategory('鬼畜', 119),
  BiliCategory('舞蹈', 129),
  BiliCategory('娱乐', 5),
  BiliCategory('科技数码', 188),
  BiliCategory('美食', 211),
  BiliCategory('电影', 23),
  BiliCategory('电视剧', 11),
  BiliCategory('纪录片', 177),
  BiliCategory('游戏', 4),
  BiliCategory('音乐', 3),
  BiliCategory('影视', 181),
  BiliCategory('知识', 36),
  BiliCategory('资讯', 202),
];

const List<BiliCategory> kMoreBiliCategories = [
  BiliCategory('运动', 234),
  BiliCategory('汽车', 223),
  BiliCategory('生活', 160),
  BiliCategory('动物圈', 217),
  BiliCategory('时尚', 155),
];

const List<BiliCategory> kAllBiliCategories = [
  ...kBiliCategories,
  ...kMoreBiliCategories,
];

class CategoryBar extends StatefulWidget {
  const CategoryBar({
    super.key,
    required this.page,
    required this.feedIndex,
    required this.onSelectFeed,
    required this.onRestoreSearch,
  });

  /// 当前页：0=主页，1=下载页，2=UP 空间。非主页时不高亮任何分区。
  final int page;

  /// 当前 feed：-1=搜索结果，0=推荐，n 对应 `kAllBiliCategories[n - 1]`。
  final int feedIndex;

  /// 选中分区，参数为 feed 序号（0 为推荐，i + 1 为 `kAllBiliCategories[i]`）。
  final ValueChanged<int> onSelectFeed;
  final VoidCallback onRestoreSearch;

  @override
  State<CategoryBar> createState() => _CategoryBarState();
}

class _CategoryBarState extends State<CategoryBar> {
  bool _showMore = false;

  Widget _chip(
    String label,
    bool selected,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    final foreground = selected
        ? const Color(0xFFB8CBFF)
        : const Color(0xFF929BAD);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? Color(0xFF1B2A4A).withValues(alpha: 0.6) : SurfaceSettings.instance.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF385A9F) : const Color(0xFF232A36),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: foreground),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    const visibleCategories = [
      '番剧',
      '国创',
      '综艺',
      '动画',
      '鬼畜',
      '舞蹈',
      '娱乐',
      '科技数码',
      '美食',
    ];
    const hiddenCategories = [
      '电影',
      '电视剧',
      '纪录片',
      '游戏',
      '音乐',
      '影视',
      '知识',
      '资讯',
      '运动',
      '汽车',
      '生活',
      '动物圈',
      '时尚',
    ];

    int indexOfCategory(String name) =>
        kAllBiliCategories.indexWhere((category) => category.name == name);

    Widget categoryChip(String name) {
      final index = indexOfCategory(name);
      return _chip(
        name,
        widget.page == 0 && widget.feedIndex == index + 1,
        () => widget.onSelectFeed(index + 1),
      );
    }

    final firstRow = <Widget>[
      _chip(
        '搜索结果',
        widget.page == 0 && widget.feedIndex == -1,
        widget.onRestoreSearch,
      ),
      _chip(
        '推荐',
        widget.page == 0 && widget.feedIndex == 0,
        () => widget.onSelectFeed(0),
      ),
      for (final name in visibleCategories) categoryChip(name),
      _chip(
        _showMore ? '收起' : '更多',
        false,
        () => setState(() => _showMore = !_showMore),
        icon: _showMore ? Icons.expand_less : Icons.expand_more,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: gap,
            runSpacing: gap,
            children: firstRow,
          ),
          if (_showMore) ...[
            const SizedBox(height: gap),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final name in hiddenCategories) categoryChip(name),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
