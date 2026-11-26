// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter/material.dart';

import '../bili/history.dart';
import '../bili/models.dart';

/// 播放历史弹窗：点击某条返回该条记录，由主页面负责续播
class HistoryDialog extends StatefulWidget {
  const HistoryDialog({
    super.key,
    required this.store,
    this.cloudEntries = const [],
  });

  final HistoryStore store;

  /// B站云端历史（已登录且拉取成功时传入），与本地记录合并展示
  final List<HistoryEntry> cloudEntries;

  @override
  State<HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends State<HistoryDialog> {
  /// 本地与云端按 key 合并，取更新时间较新的一条
  List<HistoryEntry> _merged() {
    final map = <String, HistoryEntry>{};
    for (final entry in widget.store.entries) {
      map[entry.key] = entry;
    }
    for (final entry in widget.cloudEntries) {
      final local = map[entry.key];
      if (local == null || entry.updatedAt > local.updatedAt) {
        map[entry.key] = entry;
      }
    }
    final list = map.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _merged();
    return Dialog(
      backgroundColor: const Color(0xFF14171C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 720,
        height: 560,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.history, size: 18, color: Color(0xFFC9CDD4)),
                  const SizedBox(width: 8),
                  const Text(
                    '播放历史',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entries.length} 条',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6E7480)),
                  ),
                  if (widget.cloudEntries.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2A4A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '已同步云端',
                        style: TextStyle(fontSize: 10, color: Color(0xFF7C93FF)),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (entries.isNotEmpty)
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text('清空', style: TextStyle(fontSize: 12)),
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFF23262D)),
            Expanded(
              child: entries.isEmpty
                  ? const Center(
                      child: Text(
                        '还没有播放记录',
                        style: TextStyle(color: Color(0xFF8B9099), fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _buildRow(entry);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(HistoryEntry entry) {
    final progressLabel = entry.positionSeconds > 0
        ? '看到 ${formatSeconds(entry.positionSeconds)} / ${formatSeconds(entry.durationSeconds)}'
        : (entry.finished && !entry.fromCloud
            ? '已看完 · ${formatSeconds(entry.durationSeconds)}'
            : '未观看${entry.durationSeconds > 0 ? ' · ${formatSeconds(entry.durationSeconds)}' : ''}');
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).pop(entry),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF171A20),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 120,
                height: 68,
                child: entry.cover.isEmpty
                    ? Container(color: const Color(0xFF23262D))
                    : Image.network(
                        entry.cover,
                        fit: BoxFit.cover,
                        headers: const {'Referer': 'https://www.bilibili.com/'},
                        errorBuilder: (_, __, ___) =>
                            Container(color: const Color(0xFF23262D)),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (entry.fromCloud) ...[
                        const Icon(Icons.cloud_queue,
                            size: 12, color: Color(0xFF7C93FF)),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  if (entry.partTitle.isNotEmpty &&
                      entry.partTitle != entry.title) ...[
                    const SizedBox(height: 3),
                    Text(
                      entry.partTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8B9099)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: entry.progress,
                      minHeight: 3,
                      backgroundColor: const Color(0xFF23262D),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Color(0xFF4C6EF5)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progressLabel,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF6E7480)),
                  ),
                ],
              ),
            ),
            if (entry.fromCloud)
              const Padding(
                padding: EdgeInsets.only(right: 8, left: 4),
                child: Tooltip(
                  message: '云端记录，请在 B站 删除',
                  child: Icon(Icons.cloud_done,
                      size: 16, color: Color(0xFF4C6EF5)),
                ),
              )
            else
              IconButton(
                tooltip: '删除这条记录',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                icon: const Icon(Icons.delete_outline, color: Color(0xFF6E7480)),
                onPressed: () async {
                  await widget.store.remove(entry.key);
                  if (mounted) setState(() {});
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空播放历史'),
        content: Text(
          widget.cloudEntries.isEmpty
              ? '所有播放记录和续播进度都会被删除，确定吗？'
              : '会清空本机记录；云端记录需要在 B站 里删除。确定吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.store.clear();
      if (mounted) setState(() {});
    }
  }
}
