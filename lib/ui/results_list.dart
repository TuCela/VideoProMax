import 'package:flutter/material.dart';

import '../bili/client.dart' show kUserAgent;
import '../bili/models.dart';
import 'search_filter_bar.dart';

/// 左侧搜索结果 / 推荐 / 分区列表。
///
/// 负责标题行、收起入口、搜索筛选区、视频卡片与列表末尾的加载状态；
/// 滚动续页由页面通过 [scrollController] 监听，不在本组件内处理。
class ResultsList extends StatelessWidget {
  const ResultsList({
    super.key,
    required this.title,
    required this.items,
    required this.loading,
    required this.feedLoading,
    required this.hasMore,
    required this.scrollController,
    required this.onTap,
    required this.onCollapse,
    this.message,
    this.onRefresh,
    this.currentBvid,
    this.currentSeasonId,
    this.showFilter = false,
    this.filter = const SearchFilter(),
    this.onFilterChanged,
  });

  /// 标题：搜索结果 / 推荐 / 分区名。
  final String title;

  final List<VideoItem> items;

  /// 首屏加载中（列表为空时显示居中转圈）。
  final bool loading;

  /// 续页加载中（列表末尾显示小转圈）。
  final bool feedLoading;

  final bool hasMore;
  final String? message;

  final ScrollController scrollController;
  final ValueChanged<VideoItem> onTap;

  /// 收起左侧栏；为 null 时不显示收起按钮。
  final VoidCallback onCollapse;

  /// 刷新当前 feed；为 null 时不显示刷新按钮（搜索结果没有刷新）。
  final VoidCallback? onRefresh;

  /// 当前正在播放的视频，用于高亮。
  final String? currentBvid;
  final int? currentSeasonId;

  final bool showFilter;
  final SearchFilter filter;
  final ValueChanged<SearchFilter>? onFilterChanged;

  bool _isPlaying(VideoItem item) {
    if (item.seasonId != null) return currentSeasonId == item.seasonId;
    return currentBvid == item.bvid;
  }

  Widget _tile(VideoItem item) {
    final selected = _isPlaying(item);
    final authorLine = (item.subtitle?.isNotEmpty ?? false)
        ? item.subtitle!
        : item.author;
    final meta = [
      if (item.play > 0) item.playText,
      if (item.durationSeconds > 0) item.durationText,
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => onTap(item),
      child: Stack(
        clipBehavior: Clip.antiAlias,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF1B2A4A) : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: selected ? const Color(0xFF385A9F) : Colors.transparent,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 144,
                    height: 82,
                    child: item.cover.isEmpty
                        ? Container(color: const Color(0xFF23262D))
                        : Image.network(
                            item.cover,
                            fit: BoxFit.cover,
                            headers: const {
                              'Referer': 'https://www.bilibili.com/',
                              'User-Agent': kUserAgent,
                            },
                            errorBuilder: (_, __, ___) =>
                                Container(color: const Color(0xFF23262D)),
                          ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        authorLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF929BAD),
                        ),
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF657086),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (selected)
            Positioned(
              left: 0,
              top: 10,
              bottom: 10,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF5B8CFF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          message ?? '暂无内容',
          style: const TextStyle(color: Color(0xFF8B9099)),
        ),
      );
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: items.length + 1, // 末尾加载状态行
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == items.length) {
          // 列表末尾：加载中 / 没有更多。
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: feedLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      hasMore ? '上滑加载更多' : '没有更多了',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7079),
                      ),
                    ),
            ),
          );
        }
        return _tile(items[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF10141B),
      child: Column(
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.only(left: 14, right: 6),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${items.length} 个视频',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF657086),
                  ),
                ),
                // 紧贴标题右侧：收起搜索结果栏，字号与标题一致。
                TextButton(
                  onPressed: onCollapse,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 26),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: const Color(0xFF9FB0FF),
                  ),
                  child: const Text('收起', style: TextStyle(fontSize: 13)),
                ),
                const Spacer(),
                if (onRefresh != null)
                  IconButton(
                    tooltip: '刷新',
                    visualDensity: VisualDensity.compact,
                    iconSize: 16,
                    onPressed: feedLoading ? null : onRefresh,
                    icon: const Icon(Icons.refresh, color: Color(0xFF8B9099)),
                  ),
              ],
            ),
          ),
          // 筛选区放在搜索结果区域顶部（列表上方）。
          if (showFilter && onFilterChanged != null)
            SearchFilterBar(filter: filter, onChanged: onFilterChanged!),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}
