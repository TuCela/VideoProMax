// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:async';

import 'package:flutter/material.dart';

import '../bili/client.dart';
import '../bili/models.dart';
import 'surface_settings.dart';

/// 独立的 UP 主空间页面。
///
/// 顶部左侧 1/3 显示头像/昵称/简介，右侧是「UP投稿 / UP动态 / UP合集」入口。
/// 下方窗口按当前 tab 渲染投稿视频、空间动态或合集列表。
class SpacePage extends StatefulWidget {
  const SpacePage({
    super.key,
    required this.client,
    required this.mid,
    required this.onPlay,
  });

  final BiliClient client;
  final int mid;
  final ValueChanged<VideoItem> onPlay;

  @override
  State<SpacePage> createState() => _SpacePageState();
}

class _SpacePageState extends State<SpacePage> {
  final ScrollController _scroll = ScrollController();

  static const int _tabVideos = 0;
  static const int _tabDynamics = 1;
  static const int _tabCollections = 2;

  int _tab = _tabVideos;
  UpInfo? _info;

  // 投稿
  List<VideoItem> _items = const [];
  int _count = 0;
  int _page = 1;
  String _order = 'pubdate';

  // 动态
  List<UpDynamic> _dynamics = const [];
  String _dynamicOffset = '';

  // 合集
  List<UpCollection> _collections = const [];

  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    unawaited(_load(reset: true));
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || !_hasMore) return;
    // 合集接口一次性返回全部，不需要续页。
    if (_tab == _tabCollections) return;
    final pos = _scroll.position;
    if (pos.pixels > pos.maxScrollExtent - 400) {
      unawaited(_load(reset: false));
    }
  }

  void _switchTab(int tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _error = null;
      _items = const [];
      _dynamics = const [];
      _collections = const [];
      _count = 0;
      _page = 1;
      _dynamicOffset = '';
      _hasMore = true;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    unawaited(_load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    if (_loading) return;
    final nextPage = _page + 1;
    setState(() {
      _loading = true;
      if (reset) _error = null;
    });
    try {
      UpInfo? info;
      if (_info == null) {
        info = await widget.client.fetchUpInfo(widget.mid);
      }
      if (!mounted) return;

      if (_tab == _tabVideos) {
        final result = await widget.client.fetchUpVideos(
          widget.mid,
          pn: reset ? 1 : nextPage,
          order: _order,
          face: info?.face ?? _info?.face ?? '',
        );
        if (!mounted) return;
        setState(() {
          _info = info ?? _info;
          if (reset) {
            _items = result.items;
            _page = 1;
          } else {
            _items = [..._items, ...result.items];
            _page = nextPage;
          }
          _count = result.count;
          // 去重后新增为 0 也视为没有更多。
          _hasMore = result.items.isNotEmpty && _items.length < _count;
        });
      } else if (_tab == _tabDynamics) {
        final result = await widget.client.fetchUpDynamics(
          widget.mid,
          offset: reset ? '' : _dynamicOffset,
        );
        if (!mounted) return;
        setState(() {
          _info = info ?? _info;
          _dynamics = reset ? result.items : [..._dynamics, ...result.items];
          _dynamicOffset = result.offset;
          _hasMore = result.hasMore && result.items.isNotEmpty;
        });
      } else {
        final result = await widget.client.fetchUpCollections(widget.mid);
        if (!mounted) return;
        setState(() {
          _info = info ?? _info;
          _collections = result;
          _hasMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeOrder(String order) {
    if (_order == order) return;
    setState(() {
      _order = order;
      _items = const [];
      _count = 0;
      _page = 1;
      _hasMore = true;
    });
    unawaited(_load(reset: true));
  }

  void _playDynamic(UpDynamic item) {
    if (item.bvid.isEmpty) return;
    widget.onPlay(
      VideoItem(
        bvid: item.bvid,
        title: item.title.isNotEmpty ? item.title : item.text,
        author: _info?.name ?? '',
        cover: item.cover,
        play: 0,
        durationSeconds: 0,
        pubdate: 0,
        mid: widget.mid,
        face: _info?.face ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mid <= 0) {
      return const Center(
        child: Text(
          '请先扫码登录，再打开 UP 首页',
          style: TextStyle(fontSize: 13, color: Color(0xFF8B9099)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfile(),
        Expanded(
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              ..._contentSlivers(),
              if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      '加载失败：$_error',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF9A9A),
                      ),
                    ),
                  ),
                ),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (!_hasMore && _items.isNotEmpty && _tab == _tabVideos)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        '没有更多了',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6E7480),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// 资料区：横幅头像 + 昵称/签名/数据，下方放置内容标签。
  Widget _buildProfile() {
    final info = _info;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF23262D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 154,
            decoration: const BoxDecoration(
              color: Color(0xFF12332F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 40,
                  top: -92,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  right: 150,
                  top: 24,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2DD4BF).withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  bottom: 18,
                  child: _avatar(info, size: 70),
                ),
                Positioned(
                  left: 104,
                  right: 18,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              info?.name ?? '加载中…',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF0F7F5),
                              ),
                            ),
                          ),
                          if (info != null && info.level > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2DD4BF)
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                'LV${info.level}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF9AF2E5),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (info != null && info.sign.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SelectableText(
                          info.sign,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: Color(0xFFA7C9C3),
                          ),
                        ),
                      ],
                      if (info != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          [
                            if (info.following >= 0)
                              '${_countText(info.following)} 关注',
                            '${_countText(info.follower)} 粉丝',
                            if (info.likes > 0) '${_countText(info.likes)} 获赞',
                          ].join('  ·  '),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF7FA9A1),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: const Border(top: BorderSide(color: Color(0xFF27323F))),
            ),
            child: Row(
              children: [
                _buildTabBar(),
                const Spacer(),
                Text(
                  'UP 主空间',
                  style: TextStyle(fontSize: 10, color: Color(0xFF5E6D7E)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(UpInfo? info, {double size = 52}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2A2E36),
        border: Border.all(color: const Color(0xFF7C93FF), width: 2),
        image: info != null && info.face.isNotEmpty
            ? DecorationImage(image: NetworkImage(info.face), fit: BoxFit.cover)
            : null,
      ),
      child: info == null || info.face.isEmpty
          ? const Icon(Icons.person, size: 22, color: Color(0xFF8B9099))
          : null,
    );
  }

  /// 三个入口收成一条紧凑分段控件，替代原来三个通栏大按钮。
  Widget _buildTabBar() {
    Widget item(IconData icon, String label, int tab) {
      final selected = _tab == tab;
      return InkWell(
        onTap: () => _switchTab(tab),
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2E3A8C) : SurfaceSettings.instance.color,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected
                    ? const Color(0xFFC9D4FF)
                    : const Color(0xFF7E848E),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected
                      ? const Color(0xFFDCE4FF)
                      : const Color(0xFF9AA0AA),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: SurfaceSettings.instance.color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A2E36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(Icons.video_library_outlined, 'UP投稿', _tabVideos),
          item(Icons.dynamic_feed_outlined, 'UP动态', _tabDynamics),
          item(Icons.folder_copy_outlined, 'UP合集', _tabCollections),
        ],
      ),
    );
  }

  List<Widget> _contentSlivers() {
    final empty = !_loading && _error == null;

    if (_tab == _tabDynamics) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: _sectionTitle(
              'UP动态',
              _dynamics.isNotEmpty ? '${_dynamics.length} 条' : '',
            ),
          ),
        ),
        if (_dynamics.isEmpty && empty)
          SliverToBoxAdapter(child: _emptyHint('该 UP 主还没有发布动态'))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _dynamicTile(_dynamics[index]),
                childCount: _dynamics.length,
              ),
            ),
          ),
      ];
    }

    if (_tab == _tabCollections) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: _sectionTitle(
              'UP合集',
              _collections.isNotEmpty ? '${_collections.length} 个' : '',
            ),
          ),
        ),
        if (_collections.isEmpty && empty)
          SliverToBoxAdapter(child: _emptyHint('该 UP 主还没有创建合集'))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _collectionTile(_collections[index]),
                childCount: _collections.length,
              ),
            ),
          ),
      ];
    }

    // 投稿：标题与排序合并为一行，减少一层多余的纵向堆叠。
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              _sectionTitle('投稿视频', _count > 0 ? '共 $_count 个' : ''),
              const Spacer(),
              _orderChip('最新发布', 'pubdate'),
              const SizedBox(width: 6),
              _orderChip('最多播放', 'click'),
            ],
          ),
        ),
      ),
      if (_items.isEmpty && empty)
        SliverToBoxAdapter(child: _emptyHint('该 UP 主还没有投稿视频'))
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.crossAxisExtent;
              final columns = width >= 1100
                  ? 5
                  : width >= 850
                  ? 4
                  : width >= 600
                  ? 3
                  : 2;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: 1.12,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _videoTile(_items[index]),
                  childCount: _items.length,
                ),
              );
            },
          ),
        ),
    ];
  }

  /// 区块标题：主标题 + 灰色计数。
  Widget _sectionTitle(String title, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE8EAED),
          ),
        ),
        if (count.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              count,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6E7480)),
            ),
          ),
      ],
    );
  }

  /// 排序切换：轻量描边胶囊，选中带勾。
  Widget _orderChip(String label, String order) {
    final selected = _order == order;
    return InkWell(
      onTap: () => _changeOrder(order),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF232B47) : SurfaceSettings.instance.color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? const Color(0xFF3E5BD6) : const Color(0xFF2A2E36),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 12, color: Color(0xFF9FB0FF)),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? const Color(0xFFC9D4FF)
                    : const Color(0xFF9AA0AA),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 28,
              color: Color(0xFF3A3F48),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6E7480)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dynamicTile(UpDynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SurfaceSettings.instance.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF23262D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.timeText.isNotEmpty)
            Text(
              item.timeText,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6E7480)),
            ),
          const SizedBox(height: 5),
          if (item.text.isNotEmpty)
            SelectableText(
              item.text,
              maxLines: 4,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFFDDDDDD),
                height: 1.4,
              ),
            ),
          if (item.title.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _playDynamic(item),
              child: Row(
                children: [
                  if (item.cover.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 100,
                        height: 58,
                        child: Image.network(
                          item.cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: const Color(0xFF23262D)),
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFE8EAED),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (item.playText.isNotEmpty) item.playText,
                            if (item.durationText.isNotEmpty) item.durationText,
                          ].join(' · '),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8B9099),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (item.cover.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  item.cover,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: const Color(0xFF23262D)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _collectionTile(UpCollection item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SurfaceSettings.instance.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF23262D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.cover.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 110,
                    height: 64,
                    child: Image.network(
                      item.cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: const Color(0xFF23262D)),
                    ),
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE8EAED),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '共 ${item.total} 个视频',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8B9099),
                      ),
                    ),
                    if (item.description.isNotEmpty)
                      SelectableText(
                        item.description,
                        maxLines: 2,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6E7480),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (item.videos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final video in item.videos.take(6))
                  InkWell(
                    onTap: () => widget.onPlay(video),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF20242C),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFC9CDD4),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _videoTile(VideoItem item) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => widget.onPlay(item),
      child: Container(
        decoration: BoxDecoration(
          color: SurfaceSettings.instance.color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF23262D)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: item.cover.isEmpty
                  ? Container(color: const Color(0xFF23262D))
                  : Image.network(
                      item.cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: const Color(0xFF23262D)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE8EAED),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_countText(item.play)}播放 · ${item.durationText}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF8B9099),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _countText(int n) {
    if (n >= 100000000) return '${(n / 100000000).toStringAsFixed(1)}亿';
    if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}万';
    return '$n';
  }
}
