// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter/material.dart';

import '../bili/client.dart';
import '../bili/models.dart';

/// 评论区面板：对齐 B站官方网页版的功能。
///
/// 官方评论区包含：置顶评论、UP主标记、评论者等级、点赞、回复、
/// 楼中楼（预览 + 展开 + 分页）、最热/最新排序、评论总数、
/// 长评论折叠。
///
/// 放在选集区下方，作为播放器详情的一部分。
class CommentsPanel extends StatefulWidget {
  const CommentsPanel({
    super.key,
    required this.client,
    required this.oid,
    required this.isLoggedIn,
    required this.onNeedLogin,
  });

  final BiliClient client;
  /// 视频 aid（评论用 oid=aid, type=1）。<=0 时不显示评论。
  final int oid;
  final bool isLoggedIn;
  final VoidCallback onNeedLogin;

  @override
  State<CommentsPanel> createState() => _CommentsPanelState();
}

/// 超过这个字符数的评论默认折叠。
const int _kLongCommentChars = 60;

class _CommentsPanelState extends State<CommentsPanel> {
  final List<CommentItem> _items = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  int _mode = 3; // 3=最热 2=最新
  int _next = 0;
  bool _isEnd = false;
  bool _loading = false;
  bool _sending = false;
  int _total = 0;
  String? _error;
  final Set<int> _likedLocal = {};

  /// 正在回复的评论（null = 发主评论）。
  CommentItem? _replyTarget;
  final TextEditingController _replyCtrl = TextEditingController();
  bool _sendingReply = false;

  /// 展开的楼中楼：评论 rpid -> 回复列表。
  final Map<int, List<CommentItem>> _replies = {};
  final Set<int> _repliesExpanded = {};
  final Set<int> _repliesLoading = {};
  /// 楼中楼已加载的页数，用于「加载更多回复」。
  final Map<int, int> _repliesPage = {};

  /// 手动展开全文的长评论 rpid。
  final Set<int> _expandedComments = {};

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void didUpdateWidget(CommentsPanel old) {
    super.didUpdateWidget(old);
    if (old.oid != widget.oid) {
      _replies.clear();
      _repliesExpanded.clear();
      _repliesLoading.clear();
      _repliesPage.clear();
      _expandedComments.clear();
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _loading || _isEnd) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (widget.oid <= 0) return;
    setState(() {
      _loading = true;
      if (reset) {
        _items.clear();
        _next = 0;
        _isEnd = false;
        _error = null;
      }
    });
    try {
      final page = await widget.client.fetchComments(
        widget.oid,
        mode: _mode,
        next: _next,
      );
      if (!mounted) return;
      setState(() {
        for (final item in page.items) {
          if (!_items.any((e) => e.rpid == item.rpid)) _items.add(item);
        }
        _next = page.next;
        _isEnd = page.isEnd || page.items.isEmpty;
        _total = page.total;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    if (!widget.isLoggedIn) {
      widget.onNeedLogin();
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.client.sendComment(widget.oid, text);
      _inputCtrl.clear();
      await _load(reset: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发表失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendReply(CommentItem target) async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    if (!widget.isLoggedIn) {
      widget.onNeedLogin();
      return;
    }
    setState(() => _sendingReply = true);
    try {
      await widget.client.sendComment(
        widget.oid,
        text,
        parent: target.rpid,
      );
      _replyCtrl.clear();
      // 回复成功后刷新该楼中楼。
      setState(() {
        _replyTarget = null;
        _repliesExpanded.add(target.rpid);
      });
      await _loadReplies(target.rpid, force: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('回复失败：$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingReply = false);
    }
  }

  Future<void> _loadReplies(
    int root, {
    bool force = false,
    int? pn,
  }) async {
    if (_repliesLoading.contains(root)) return;
    final page = pn ?? 1;
    if (!force && pn == null && _replies.containsKey(root)) return;
    setState(() => _repliesLoading.add(root));
    final list = await widget.client.fetchReplies(widget.oid, root, pn: page);
    if (!mounted) return;
    setState(() {
      final existing = _replies[root] ?? [];
      final merged = [...existing];
      for (final r in list) {
        if (!merged.any((e) => e.rpid == r.rpid)) merged.add(r);
      }
      _replies[root] = merged;
      _repliesPage[root] = page;
      _repliesLoading.remove(root);
    });
  }

  void _toggleReplies(CommentItem item) {
    final expanded = _repliesExpanded.contains(item.rpid);
    setState(() {
      if (expanded) {
        _repliesExpanded.remove(item.rpid);
      } else {
        _repliesExpanded.add(item.rpid);
        // 优先直接用接口内置的楼中楼预览，无需再发请求。
        if (!_replies.containsKey(item.rpid)) {
          if (item.previewReplies.isNotEmpty) {
            _replies[item.rpid] = item.previewReplies;
            _repliesPage[item.rpid] = 1;
          } else {
            _loadReplies(item.rpid);
          }
        }
      }
    });
  }

  Future<void> _toggleLike(CommentItem item) async {
    if (!widget.isLoggedIn) {
      widget.onNeedLogin();
      return;
    }
    final liked = _likedLocal.contains(item.rpid);
    setState(() {
      if (liked) {
        _likedLocal.remove(item.rpid);
      } else {
        _likedLocal.add(item.rpid);
      }
    });
    try {
      await widget.client.likeComment(widget.oid, item.rpid, like: !liked);
    } catch (e) {
      // 失败回滚。
      setState(() {
        if (liked) {
          _likedLocal.add(item.rpid);
        } else {
          _likedLocal.remove(item.rpid);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('点赞失败：$e')),
        );
      }
    }
  }

  Future<void> _toggleSubLike(CommentItem sub) async {
    if (!widget.isLoggedIn) {
      widget.onNeedLogin();
      return;
    }
    final liked = _likedLocal.contains(sub.rpid);
    setState(() {
      if (liked) {
        _likedLocal.remove(sub.rpid);
      } else {
        _likedLocal.add(sub.rpid);
      }
    });
    try {
      await widget.client.likeSubReply(widget.oid, sub.rpid, like: !liked);
    } catch (e) {
      setState(() {
        if (liked) {
          _likedLocal.add(sub.rpid);
        } else {
          _likedLocal.remove(sub.rpid);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('点赞失败：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.oid <= 0) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.comment, size: 18, color: Color(0xFFC9CDD4)),
            const SizedBox(width: 8),
            Text(
              '$_total 条评论',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE0E3E8),
              ),
            ),
            const Spacer(),
            _sortButton('最热', 3),
            const SizedBox(width: 4),
            _sortButton('最新', 2),
          ],
        ),
        const SizedBox(height: 8),
        // 发表评论输入框
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                decoration: InputDecoration(
                  hintText: widget.isLoggedIn ? '发一条友善的评论' : '登录后发表评论',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF171A20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: Text(_sending ? '发送中' : '发送'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _error!,
              style: const TextStyle(fontSize: 12, color: Color(0xFFFF8787)),
            ),
          ),
        // 评论列表（固定高度，内部可滚动，触发自动加载下一页）
        SizedBox(
          height: 320,
          child: ListView.separated(
            controller: _scrollCtrl,
            itemCount: _items.length + (_loading ? 1 : 0),
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              color: Color(0xFF23262D),
            ),
            itemBuilder: (_, i) {
              if (i >= _items.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return _commentTile(_items[i]);
            },
          ),
        ),
        if (_isEnd && _items.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                '没有更多评论了',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7079)),
              ),
            ),
          ),
      ],
    );
  }

  /// 判断是不是置顶评论：接口的 top_replies 会排在最前并带 isTop 标记。
  bool _isTopItem(CommentItem item) => item.isTop;

  Widget _sortButton(String label, int mode) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () {
        if (_mode != mode) {
          setState(() => _mode = mode);
          _load(reset: true);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF4C6EF5) : const Color(0xFF1A1D24),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : const Color(0xFFC9CDD4),
          ),
        ),
      ),
    );
  }

  /// 评论者等级徽章（B站 0~6 级）。
  Widget _levelBadge(int level) {
    if (level <= 0) return const SizedBox.shrink();
    const colors = [
      Color(0xFF8B9099),
      Color(0xFF9FB0FF),
      Color(0xFF69DB7C),
      Color(0xFF4DABF7),
      Color(0xFFFFB86B),
      Color(0xFFFF8787),
      Color(0xFFDDA0DD),
    ];
    final color = colors[level.clamp(0, 6)];
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 0.5),
      ),
      child: Text(
        'LV$level',
        style: TextStyle(fontSize: 9, color: color, height: 1.2),
      ),
    );
  }

  Widget _commentTile(CommentItem item) {
    final liked = _likedLocal.contains(item.rpid);
    final isTop = _isTopItem(item);
    final isLong = item.message.length > _kLongCommentChars;
    final expanded = _expandedComments.contains(item.rpid);
    final showFull = !isLong || expanded;
    final repliesOpen = _repliesExpanded.contains(item.rpid);
    final loadingReplies = _repliesLoading.contains(item.rpid);
    final replyTarget = _replyTarget?.rpid == item.rpid ? _replyTarget : null;
    final replyList = _replies[item.rpid];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage:
                    item.avatar.isNotEmpty ? NetworkImage(item.avatar) : null,
                child: item.avatar.isEmpty
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.uname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9FB0FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _levelBadge(item.level),
                        if (isTop)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB86B).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              '置顶',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFFFFB86B),
                                height: 1.2,
                              ),
                            ),
                          ),
                        if (item.isUpper)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C93FF).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'UP',
                              style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFF7C93FF),
                                height: 1.2,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 长评论默认最多 3 行，超出部分折叠。
                    SelectableText(
                      item.message,
                      maxLines: showFull ? null : 3,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFDDDDDD),
                      ),
                    ),
                    if (isLong)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (expanded) {
                              _expandedComments.remove(item.rpid);
                            } else {
                              _expandedComments.add(item.rpid);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            expanded ? '收起' : '展开',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF7C93FF),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          item.timeText,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8B9099),
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => _toggleLike(item),
                          child: Row(
                            children: [
                              Icon(
                                Icons.thumb_up_alt_outlined,
                                size: 14,
                                color: liked
                                    ? const Color(0xFF9FB0FF)
                                    : const Color(0xFF8B9099),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${item.like + (liked ? 1 : 0)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: liked
                                      ? const Color(0xFF9FB0FF)
                                      : const Color(0xFF8B9099),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _replyTarget =
                                  _replyTarget?.rpid == item.rpid ? null : item;
                            });
                          },
                          child: Row(
                            children: [
                              const Icon(
                                Icons.reply,
                                size: 14,
                                color: Color(0xFF8B9099),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '回复',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _replyTarget?.rpid == item.rpid
                                      ? const Color(0xFF9FB0FF)
                                      : const Color(0xFF8B9099),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (item.replyCount > 0) ...[
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => _toggleReplies(item),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.forum_outlined,
                                  size: 14,
                                  color: Color(0xFF8B9099),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  repliesOpen ? '收起回复' : item.replyText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF8B9099),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    // 回复输入框
                    if (replyTarget != null) _replyInput(item),
                    // 楼中楼列表
                    if (repliesOpen) _repliesView(item, replyList),
                    if (loadingReplies && repliesOpen)
                      const Padding(
                        padding: EdgeInsets.only(top: 6, left: 4),
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _replyInput(CommentItem target) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _replyCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '回复 @${target.uname}',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                filled: true,
                fillColor: const Color(0xFF12151B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendReply(target),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _sendingReply ? null : () => _sendReply(target),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(_sendingReply ? '发送中' : '回复'),
          ),
        ],
      ),
    );
  }

  Widget _repliesView(CommentItem item, List<CommentItem>? replies) {
    if (replies == null || replies.isEmpty) {
      return const SizedBox.shrink();
    }
    final loaded = _repliesPage[item.rpid] ?? 1;
    // 已加载数量小于总回复数 → 还能继续翻页。
    final canLoadMore = loaded * 20 < item.replyCount;
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF12151B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in replies) _subReplyRow(r),
          if (canLoadMore)
            GestureDetector(
              onTap: () => _loadReplies(item.rpid, pn: loaded + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_repliesLoading.contains(item.rpid))
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(
                        Icons.expand_more,
                        size: 14,
                        color: Color(0xFF7C93FF),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      '加载更多回复',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7C93FF),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _subReplyRow(CommentItem r) {
    final liked = _likedLocal.contains(r.rpid);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundImage:
                r.avatar.isNotEmpty ? NetworkImage(r.avatar) : null,
            child: r.avatar.isEmpty
                ? const Icon(Icons.person, size: 12)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        r.uname,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9FB0FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _levelBadge(r.level),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _toggleSubLike(r),
                      child: Row(
                        children: [
                          Icon(
                            Icons.thumb_up_alt_outlined,
                            size: 12,
                            color: liked
                                ? const Color(0xFF9FB0FF)
                                : const Color(0xFF6B7079),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${r.like + (liked ? 1 : 0)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: liked
                                  ? const Color(0xFF9FB0FF)
                                  : const Color(0xFF6B7079),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                SelectableText(
                  r.message,
                  maxLines: 3,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFCCCCCC),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
