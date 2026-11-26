// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter/material.dart';

import '../bili/client.dart' show kUserAgent;
import '../bili/download_service.dart';
import '../bili/download_store.dart';

/// 下载页左侧的筛选标签。
enum DownloadFilter { downloaded, downloading, paused, failed }

/// 下载页左侧列表：按筛选显示下载记录，支持播放/重试/取消/删除。
class DownloadList extends StatefulWidget {
  const DownloadList({
    super.key,
    required this.store,
    required this.service,
    required this.onPlay,
  });

  final DownloadStore store;
  final DownloadService service;

  /// 点击一条已完成记录：播放本地文件。
  final void Function(DownloadRecord) onPlay;

  @override
  State<DownloadList> createState() => _DownloadListState();
}

class _DownloadListState extends State<DownloadList> {
  DownloadFilter? _filter;

  List<DownloadRecord> _filtered() {
    final filter = _filter;
    if (filter == null) {
      return widget.store.records.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return widget.store.records.where((r) {
      switch (filter) {
        case DownloadFilter.downloaded:
          return r.isDone;
        case DownloadFilter.downloading:
          return r.isActive;
        case DownloadFilter.paused:
          return r.isPaused;
        case DownloadFilter.failed:
          return r.isFailed;
      }
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  int _count(DownloadFilter filter) {
    return widget.store.records.where((r) {
      switch (filter) {
        case DownloadFilter.downloaded:
          return r.isDone;
        case DownloadFilter.downloading:
          return r.isActive;
        case DownloadFilter.paused:
          return r.isPaused;
        case DownloadFilter.failed:
          return r.isFailed;
      }
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered();
    return Scaffold(
      backgroundColor: const Color(0xFF0E1117),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '下载管理',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  '音视频自动合并为 MP4，支持暂停、继续、重试与本地播放。',
                  style: TextStyle(fontSize: 10, color: Color(0xFF6E7480)),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gap = 6.0;
                    final itemWidth = (constraints.maxWidth - gap * 4) / 5;
                    final compact = itemWidth < 72;
                    return SizedBox(
                      height: 52,
                      child: Row(
                        children: [
                          Expanded(
                            child: _statFilter(
                              '全部',
                              null,
                              widget.store.records.length,
                              const Color(0xFF9FB0FF),
                              Icons.apps,
                              compact: compact,
                              itemWidth: itemWidth,
                            ),
                          ),
                          const SizedBox(width: gap),
                          Expanded(
                            child: _statFilter(
                              '下载中',
                              DownloadFilter.downloading,
                              _count(DownloadFilter.downloading),
                              const Color(0xFF9FB0FF),
                              Icons.downloading,
                              compact: compact,
                              itemWidth: itemWidth,
                            ),
                          ),
                          const SizedBox(width: gap),
                          Expanded(
                            child: _statFilter(
                              '已完成',
                              DownloadFilter.downloaded,
                              _count(DownloadFilter.downloaded),
                              const Color(0xFF69DB7C),
                              Icons.check_circle_outline,
                              compact: compact,
                              itemWidth: itemWidth,
                            ),
                          ),
                          const SizedBox(width: gap),
                          Expanded(
                            child: _statFilter(
                              '已暂停',
                              DownloadFilter.paused,
                              _count(DownloadFilter.paused),
                              const Color(0xFFFFD43B),
                              Icons.pause_circle_outline,
                              compact: compact,
                              itemWidth: itemWidth,
                            ),
                          ),
                          const SizedBox(width: gap),
                          Expanded(
                            child: _statFilter(
                              '失败',
                              DownloadFilter.failed,
                              _count(DownloadFilter.failed),
                              const Color(0xFFFF8787),
                              Icons.error_outline,
                              compact: compact,
                              itemWidth: itemWidth,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.download_outlined,
                          size: 34,
                          color: Color(0xFF4A4F58),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _emptyText(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8B9099),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _tile(list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statFilter(
    String label,
    DownloadFilter? value,
    int count,
    Color color,
    IconData icon, {
    required bool compact,
    required double itemWidth,
  }) {
    final selected = _filter == value;
    return Tooltip(
      message: '$label $count',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _filter = value),
          borderRadius: BorderRadius.circular(9),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.12)
                  : const Color(0xFF141820),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: selected ? color : const Color(0xFF2A313E),
              ),
            ),
            child: compact
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(icon, size: itemWidth < 36 ? 14 : 18, color: color),
                      Positioned(
                        top: 2,
                        right: 1,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 14),
                          height: 14,
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: TextStyle(
                              fontSize: 7,
                              height: 1,
                              fontWeight: FontWeight.w700,
                              color: color == const Color(0xFFFFD43B)
                                  ? const Color(0xFF10141A)
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 5),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 8,
                              height: 1.1,
                              color: Color(0xFF6E7480),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _emptyText() {
    switch (_filter) {
      case DownloadFilter.downloaded:
        return '还没有下载完成的视频';
      case DownloadFilter.downloading:
        return '没有正在下载的任务';
      case DownloadFilter.paused:
        return '没有暂停的任务';
      case DownloadFilter.failed:
        return '没有失败的任务';
      case null:
        return '还没有下载任务';
    }
  }

  Widget _tile(DownloadRecord r) {
    final isDone = r.isDone;
    final isPaused = r.isPaused;
    final stateColor = isDone
        ? const Color(0xFF69DB7C)
        : isPaused
        ? const Color(0xFFFFD43B)
        : r.isFailed
        ? const Color(0xFFFF8787)
        : const Color(0xFF9FB0FF);
    final stateIcon = isDone
        ? Icons.check_circle_outline
        : isPaused
        ? Icons.pause_circle_outline
        : r.isFailed
        ? Icons.error_outline
        : Icons.downloading;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 96,
                  height: 54,
                  child: r.cover.isEmpty
                      ? Container(
                          color: const Color(0xFF2A313E),
                          child: Icon(stateIcon, color: stateColor, size: 20),
                        )
                      : Image.network(
                          r.cover,
                          fit: BoxFit.cover,
                          headers: const {
                            'Referer': 'https://www.bilibili.com/',
                            'User-Agent': kUserAgent,
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF2A313E),
                            child: Icon(stateIcon, color: stateColor, size: 20),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${r.qualityLabel} · ${r.message}',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF8B9099),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(stateIcon, size: 12, color: stateColor),
                        const SizedBox(width: 4),
                        Text(
                          '${isDone
                              ? '已完成'
                              : isPaused
                              ? '已暂停'
                              : r.isFailed
                              ? '下载失败'
                              : '下载中'}${r.progress < 1 ? ' ${(r.progress * 100).toStringAsFixed(0)}%' : ''}',
                          style: TextStyle(fontSize: 9, color: stateColor),
                        ),
                        if (r.speedText.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            r.speedText,
                            style: const TextStyle(
                              fontSize: 8,
                              color: Color(0xFF6E7480),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (r.progress < 1) ...[
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: r.progress,
                minHeight: 3,
                backgroundColor: const Color(0xFF2A2E36),
                valueColor: AlwaysStoppedAnimation<Color>(stateColor),
              ),
            ),
          ],
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isDone)
                TextButton(
                  onPressed: () => widget.onPlay(r),
                  child: const Text('播放', style: TextStyle(fontSize: 10)),
                ),
              if (isPaused)
                TextButton(
                  onPressed: () => widget.service.resume(r.key),
                  child: const Text('继续', style: TextStyle(fontSize: 10)),
                ),
              if (r.isFailed)
                TextButton(
                  onPressed: () => widget.service.retry(r.key),
                  child: const Text('重试', style: TextStyle(fontSize: 10)),
                ),
              if (r.isActive)
                TextButton(
                  onPressed: () => widget.service.pause(r.key),
                  child: const Text('暂停', style: TextStyle(fontSize: 10)),
                ),
              if (r.isActive)
                TextButton(
                  onPressed: () => widget.service.cancel(r.key),
                  child: const Text('取消', style: TextStyle(fontSize: 10)),
                ),
              TextButton(
                onPressed: () => widget.service.remove(r.key),
                child: const Text(
                  '删除',
                  style: TextStyle(fontSize: 10, color: Color(0xFFFF8787)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }
}
