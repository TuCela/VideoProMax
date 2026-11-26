// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter/material.dart';

import '../bili/client.dart' show kUserAgent;
import '../bili/history.dart';
import '../bili/models.dart';

enum _HistoryTimeFilter { all, today, earlier }

enum _HistorySourceFilter { all, local, cloud }

class HistoryView extends StatefulWidget {
  const HistoryView({
    super.key,
    required this.store,
    required this.cloudEntries,
    required this.onSelect,
  });

  final HistoryStore store;
  final List<HistoryEntry> cloudEntries;
  final ValueChanged<HistoryEntry> onSelect;

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistorySection {
  const _HistorySection(this.label, this.entries);

  final String label;
  final List<HistoryEntry> entries;
}

class _HistoryViewState extends State<HistoryView> {
  _HistoryTimeFilter _timeFilter = _HistoryTimeFilter.all;
  _HistorySourceFilter _sourceFilter = _HistorySourceFilter.all;

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
    return map.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  bool _matchesTime(HistoryEntry entry) {
    if (_timeFilter == _HistoryTimeFilter.all) return true;
    final date = DateTime.fromMillisecondsSinceEpoch(entry.updatedAt);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    return _timeFilter == _HistoryTimeFilter.today
        ? day == today
        : day.isBefore(today);
  }

  bool _matchesSource(HistoryEntry entry) => switch (_sourceFilter) {
    _HistorySourceFilter.all => true,
    _HistorySourceFilter.local => !entry.fromCloud,
    _HistorySourceFilter.cloud => entry.fromCloud,
  };

  List<_HistorySection> _sections(List<HistoryEntry> entries) {
    final sections = <_HistorySection>[];
    for (final entry in entries) {
      final label = _groupLabel(entry.updatedAt);
      if (sections.isEmpty || sections.last.label != label) {
        sections.add(_HistorySection(label, [entry]));
      } else {
        sections.last.entries.add(entry);
      }
    }
    return sections;
  }

  String _groupLabel(int milliseconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final month = date.month.toString().padLeft(2, '0');
    final dayOfMonth = date.day.toString().padLeft(2, '0');
    if (day == today) return '今天';
    if (day == today.subtract(const Duration(days: 1))) return '昨天';
    return date.year == now.year
        ? '$month-$dayOfMonth'
        : '${date.year}-$month-$dayOfMonth';
  }

  Widget _chip(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1B2A4A) : const Color(0xFF141820),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: active ? const Color(0xFF385A9F) : const Color(0xFF2A313E),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? const Color(0xFFB8CBFF) : const Color(0xFF929BAD),
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.transparent),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onPressed == null
                ? const Color(0xFF657086)
                : const Color(0xFF929BAD),
          ),
        ),
      ),
    );
  }

  Widget _cover(HistoryEntry entry) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        width: 144,
        height: 82,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (entry.cover.isEmpty)
              Container(color: const Color(0xFF2A313E))
            else
              Image.network(
                entry.cover,
                fit: BoxFit.cover,
                headers: const {
                  'Referer': 'https://www.bilibili.com/',
                  'User-Agent': kUserAgent,
                },
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFF2A313E)),
              ),
            if (entry.durationSeconds > 0)
              Positioned(
                right: 6,
                bottom: 6,
                child: Text(
                  formatSeconds(entry.durationSeconds),
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFFEEF1F4),
                    shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _subtitle(HistoryEntry entry) {
    if (entry.partTitle.isNotEmpty && entry.partTitle != entry.title) {
      return entry.partTitle;
    }
    return entry.kind == 'pgc' ? '版权内容' : '哔哩哔哩';
  }

  String _progressLabel(HistoryEntry entry) {
    if (entry.positionSeconds > 0) {
      return '看到 ${formatSeconds(entry.positionSeconds)} / ${formatSeconds(entry.durationSeconds)}';
    }
    if (entry.finished && !entry.fromCloud) {
      return '已看完 · ${formatSeconds(entry.durationSeconds)}';
    }
    return '未观看${entry.durationSeconds > 0 ? ' · ${formatSeconds(entry.durationSeconds)}' : ''}';
  }

  Widget _card(HistoryEntry entry, double width) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => widget.onSelect(entry),
        onSecondaryTapDown: (details) =>
            _showEntryMenu(entry, details.globalPosition),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF141820),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2A313E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cover(entry),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _subtitle(entry),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF657086),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _progressLabel(entry),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF5B8CFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.fromCloud ? '云端记录' : '本地记录',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF657086),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => widget.onSelect(entry),
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B8CFF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow, size: 12, color: Colors.white),
                          SizedBox(width: 5),
                          Text(
                            '继续播放',
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(
    _HistorySection section,
    double cardWidth,
    double availableWidth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 15,
              color: Color(0xFF929BAD),
            ),
            const SizedBox(width: 7),
            Text(
              section.label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF929BAD)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: availableWidth,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final entry in section.entries) _card(entry, cardWidth),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showEntryMenu(HistoryEntry entry, Offset globalPosition) async {
    final size = MediaQuery.sizeOf(context);
    final action = await showMenu<String>(
      context: context,
      color: const Color(0xFF141820),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF2A313E)),
      ),
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        size.width - globalPosition.dx,
        size.height - globalPosition.dy,
      ),
      items: [
        if (entry.fromCloud)
          const PopupMenuItem<String>(
            height: 36,
            enabled: false,
            child: Text(
              '云端记录，请在 B站 删除',
              style: TextStyle(fontSize: 12, color: Color(0xFF929BAD)),
            ),
          )
        else
          const PopupMenuItem<String>(
            value: 'delete',
            height: 36,
            child: Text(
              '删除这条记录',
              style: TextStyle(fontSize: 12, color: Color(0xFFEDF0F7)),
            ),
          ),
      ],
    );
    if (action == 'delete') {
      await widget.store.remove(entry.key);
      if (mounted) setState(() {});
    }
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

  @override
  Widget build(BuildContext context) {
    final allEntries = _merged();
    final entries = allEntries
        .where((entry) => _matchesTime(entry) && _matchesSource(entry))
        .toList();
    final sections = _sections(entries);

    return ColoredBox(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const padding = 22.0;
          const gap = 12.0;
          final contentWidth = (constraints.maxWidth - padding * 2).clamp(
            0.0,
            double.infinity,
          );
          final columns = (contentWidth / 340).floor().clamp(3, 6);
          final cardWidth = contentWidth > gap * (columns - 1)
              ? (contentWidth - gap * (columns - 1)) / columns
              : contentWidth;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '观看历史',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (widget.cloudEntries.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B2A4A),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '已同步云端',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF7C93FF),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '合并本地与云端记录，继续上次未看完的视频。',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF657086),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    _chip(
                      '全部',
                      _timeFilter == _HistoryTimeFilter.all,
                      () =>
                          setState(() => _timeFilter = _HistoryTimeFilter.all),
                    ),
                    _chip(
                      '今天',
                      _timeFilter == _HistoryTimeFilter.today,
                      () => setState(
                        () => _timeFilter = _HistoryTimeFilter.today,
                      ),
                    ),
                    _chip(
                      '更早',
                      _timeFilter == _HistoryTimeFilter.earlier,
                      () => setState(
                        () => _timeFilter = _HistoryTimeFilter.earlier,
                      ),
                    ),
                    _iconButton(
                      icon: Icons.delete_outline,
                      tooltip: '清空历史',
                      onPressed: allEntries.isEmpty ? null : _clearAll,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _chip(
                      '全部来源',
                      _sourceFilter == _HistorySourceFilter.all,
                      () => setState(
                        () => _sourceFilter = _HistorySourceFilter.all,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _chip(
                      '本地',
                      _sourceFilter == _HistorySourceFilter.local,
                      () => setState(
                        () => _sourceFilter = _HistorySourceFilter.local,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _chip(
                      '云端',
                      _sourceFilter == _HistorySourceFilter.cloud,
                      () => setState(
                        () => _sourceFilter = _HistorySourceFilter.cloud,
                      ),
                    ),
                  ],
                ),
                if (entries.isEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - padding * 2).clamp(
                        240.0,
                        double.infinity,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        allEntries.isEmpty ? '还没有播放记录' : '没有符合条件的播放记录',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8B9099),
                        ),
                      ),
                    ),
                  )
                else
                  for (final section in sections)
                    _section(section, cardWidth, contentWidth),
              ],
            ),
          );
        },
      ),
    );
  }
}
