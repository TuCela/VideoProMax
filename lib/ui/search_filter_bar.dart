// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter/material.dart';
import 'surface_settings.dart';

/// 搜索结果筛选条件。
class SearchFilter {
  /// 排序方式：totalrank 综合 / click 最多播放 / pubdate 最新 / dm 最多弹幕 / stow 最多收藏
  final String order;

  /// 时长：0 不限 / 1 ≤1分钟 / 2 1-4分钟 / 3 4-10分钟 / 4 ＞10分钟
  final int duration;

  /// 分区 tid，0 表示不限。
  final int tid;

  const SearchFilter({
    this.order = 'totalrank',
    this.duration = 0,
    this.tid = 0,
  });

  SearchFilter copyWith({String? order, int? duration, int? tid}) =>
      SearchFilter(
        order: order ?? this.order,
        duration: duration ?? this.duration,
        tid: tid ?? this.tid,
      );

  bool get isDefault => order == 'totalrank' && duration == 0 && tid == 0;
}

/// 排序方式选项。
class SearchOrderOption {
  final String value;
  final String label;
  const SearchOrderOption(this.value, this.label);
}

const List<SearchOrderOption> kSearchOrderOptions = [
  SearchOrderOption('totalrank', '综合排序'),
  SearchOrderOption('pubdate', '最新发布'),
  SearchOrderOption('click', '最多播放'),
  SearchOrderOption('dm', '最多弹幕'),
  SearchOrderOption('stow', '最多收藏'),
];

/// 时长选项。
class SearchDurationOption {
  final int value;
  final String label;
  const SearchDurationOption(this.value, this.label);
}

const List<SearchDurationOption> kSearchDurationOptions = [
  SearchDurationOption(0, '不限时长'),
  SearchDurationOption(1, '≤1分钟'),
  SearchDurationOption(2, '1-4分钟'),
  SearchDurationOption(3, '4-10分钟'),
  SearchDurationOption(4, '＞10分钟'),
];

/// 分区选项（tid 取 B站官网搜索筛选用的一级分区）。
class SearchTidOption {
  final int value;
  final String label;
  const SearchTidOption(this.value, this.label);
}

const List<SearchTidOption> kSearchTidOptions = [
  SearchTidOption(0, '全部分区'),
  SearchTidOption(1, '动画'),
  SearchTidOption(3, '音乐'),
  SearchTidOption(4, '游戏'),
  SearchTidOption(5, '娱乐'),
  SearchTidOption(36, '知识'),
  SearchTidOption(119, '鬼畜'),
  SearchTidOption(129, '舞蹈'),
  SearchTidOption(160, '生活'),
  SearchTidOption(181, '影视'),
  SearchTidOption(188, '科技'),
  SearchTidOption(217, '动物圈'),
  SearchTidOption(223, '汽车'),
  SearchTidOption(234, '运动'),
  SearchTidOption(155, '时尚'),
];

/// 搜索结果筛选栏：默认单行摘要，点击筛选按钮展开完整选项。
class SearchFilterBar extends StatefulWidget {
  const SearchFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  final SearchFilter filter;
  final ValueChanged<SearchFilter> onChanged;

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  bool _expanded = false;

  String get _orderLabel => kSearchOrderOptions
      .firstWhere((option) => option.value == widget.filter.order)
      .label;

  String get _durationLabel => kSearchDurationOptions
      .firstWhere((option) => option.value == widget.filter.duration)
      .label;

  String get _tidLabel => kSearchTidOptions
      .firstWhere((option) => option.value == widget.filter.tid)
      .label;

  int get _activeCount =>
      (widget.filter.order == 'totalrank' ? 0 : 1) +
      (widget.filter.duration == 0 ? 0 : 1) +
      (widget.filter.tid == 0 ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: SurfaceSettings.instance.color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A313E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _summaryMenu(
                label: _orderLabel,
                options: [
                  for (final option in kSearchOrderOptions)
                    PopupMenuItem<String>(
                      value: option.value,
                      child: Text(option.label),
                    ),
                ],
                onSelected: (value) =>
                    widget.onChanged(widget.filter.copyWith(order: value)),
              ),
              const SizedBox(width: 4),
              _summaryMenu(
                label: _durationLabel,
                options: [
                  for (final option in kSearchDurationOptions)
                    PopupMenuItem<String>(
                      value: option.value.toString(),
                      child: Text(option.label),
                    ),
                ],
                onSelected: (value) => widget.onChanged(
                  widget.filter.copyWith(duration: int.tryParse(value) ?? 0),
                ),
              ),
              const SizedBox(width: 4),
              _summaryMenu(
                label: _tidLabel,
                options: [
                  for (final option in kSearchTidOptions)
                    PopupMenuItem<String>(
                      value: option.value.toString(),
                      child: Text(option.label),
                    ),
                ],
                onSelected: (value) => widget.onChanged(
                  widget.filter.copyWith(tid: int.tryParse(value) ?? 0),
                ),
              ),
              if (_activeCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '$_activeCount',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF9FB0FF),
                    ),
                  ),
                ),
              IconButton(
                tooltip: _expanded ? '收起筛选' : '展开筛选',
                visualDensity: VisualDensity.compact,
                iconSize: 16,
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.tune,
                  color: _expanded || _activeCount > 0
                      ? const Color(0xFF9FB0FF)
                      : const Color(0xFF8B9099),
                ),
              ),
            ],
          ),
          if (_expanded) ...[
            const Divider(height: 10, color: Color(0xFF2A313E)),
            _row(
              '排序',
              kSearchOrderOptions.map(
                (option) => (
                  option.value,
                  option.label,
                  widget.filter.order == option.value,
                ),
              ),
              (value) => widget.onChanged(widget.filter.copyWith(order: value)),
            ),
            const SizedBox(height: 6),
            _row(
              '时长',
              kSearchDurationOptions.map(
                (option) => (
                  option.value.toString(),
                  option.label,
                  widget.filter.duration == option.value,
                ),
              ),
              (value) => widget.onChanged(
                widget.filter.copyWith(duration: int.tryParse(value) ?? 0),
              ),
            ),
            const SizedBox(height: 6),
            _row(
              '分区',
              kSearchTidOptions.map(
                (option) => (
                  option.value.toString(),
                  option.label,
                  widget.filter.tid == option.value,
                ),
              ),
              (value) => widget.onChanged(
                widget.filter.copyWith(tid: int.tryParse(value) ?? 0),
              ),
            ),
            if (_activeCount > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => widget.onChanged(const SearchFilter()),
                  child: const Text('清除全部', style: TextStyle(fontSize: 11)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _summaryMenu({
    required String label,
    required List<PopupMenuEntry<String>> options,
    required ValueChanged<String> onSelected,
  }) {
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (_) => options,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: SurfaceSettings.instance.color,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2A2E36)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFFC9CDD4)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 12, color: Color(0xFF6E7480)),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    Iterable<(String, String, bool)> options,
    ValueChanged<String> onPick,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7079)),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final (value, text, selected) in options)
                GestureDetector(
                  onTap: () => onPick(value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Color(0xFF4C6EF5).withValues(alpha: 0.55)
                          : SurfaceSettings.instance.color,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected
                            ? Colors.white
                            : const Color(0xFFC9CDD4),
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
}
