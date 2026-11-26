import 'package:flutter/material.dart';

import '../bili/models.dart';

/// 下载对话框中选择的一集。
class DownloadItem {
  DownloadItem({
    required this.bvid,
    required this.cid,
    required this.title,
    this.epId,
    this.cover = '',
    this.selected = true,
  });

  final String bvid;
  final String cid;
  final String title;
  final int? epId;
  final String cover;
  bool selected;
}

/// 选择结果：画质 id + 选中的剧集 + 下载设置。
class DownloadPickResult {
  DownloadPickResult({
    required this.qualityId,
    required this.items,
    required this.threads,
    required this.speedLimitMB,
  });

  final int qualityId;
  final List<DownloadItem> items;
  /// 线程数（1~16）。
  final int threads;
  /// 限速 MB/s（0 为不限速）。
  final int speedLimitMB;
}

/// 下载选择对话框：选画质 + 多选剧集。确认后由调用方投递到后台下载，
/// 本对话框不负责下载与进度（进度在下载管理页查看）。
class DownloadPickerDialog extends StatefulWidget {
  const DownloadPickerDialog({
    super.key,
    required this.items,
    required this.qualities,
    required this.initialQualityId,
    required this.downloadDir,
    required this.initialThreads,
    required this.initialSpeedLimitMB,
  });

  final List<DownloadItem> items;
  final List<DashStream> qualities;
  final int initialQualityId;
  final String downloadDir;
  final int initialThreads;
  final int initialSpeedLimitMB;

  @override
  State<DownloadPickerDialog> createState() => _DownloadPickerDialogState();
}

class _DownloadPickerDialogState extends State<DownloadPickerDialog> {
  late int _qualityId;
  late int _threads;
  late int _speedLimitMB;
  final _limitCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _qualityId = widget.initialQualityId;
    _threads = widget.initialThreads.clamp(1, 16);
    _speedLimitMB = widget.initialSpeedLimitMB;
    _limitCtrl.text = _speedLimitMB == 0 ? '' : '$_speedLimitMB';
  }

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = widget.items.where((e) => e.selected).length;
    return AlertDialog(
      title: const Text('下载视频'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '保存位置：${widget.downloadDir}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8B9099)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('画质：', style: TextStyle(fontSize: 13)),
                DropdownButton<int>(
                  value: _qualityId,
                  items: widget.qualities
                      .map(
                        (q) => DropdownMenuItem<int>(
                          value: q.id,
                          child: Text(
                            q.label,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _qualityId = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('线程：', style: TextStyle(fontSize: 13)),
                DropdownButton<int>(
                  value: _threads,
                  items: [1, 2, 4, 6, 8, 12, 16]
                      .map(
                        (n) => DropdownMenuItem<int>(
                          value: n,
                          child: Text('$n', style: const TextStyle(fontSize: 13)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _threads = v);
                  },
                ),
                const SizedBox(width: 16),
                const Text('限速：', style: TextStyle(fontSize: 13)),
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _limitCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '不限',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        _speedLimitMB = int.tryParse(v.trim()) ?? 0,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('MB/s', style: TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('选择剧集：', style: TextStyle(fontSize: 13)),
                TextButton(
                  onPressed: () => setState(() {
                    for (final e in widget.items) {
                      e.selected = !e.selected;
                    }
                  }),
                  child: const Text('反选'),
                ),
              ],
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: Column(
                  children: widget.items.map((item) {
                    return CheckboxListTile(
                      dense: true,
                      value: item.selected,
                      title: Text(
                        item.title,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: (v) =>
                          setState(() => item.selected = v ?? false),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: selectedCount == 0
              ? null
              : () => Navigator.pop(
                    context,
                    DownloadPickResult(
                      qualityId: _qualityId,
                      items: widget.items.where((e) => e.selected).toList(),
                      threads: _threads,
                      speedLimitMB: _speedLimitMB < 0 ? 0 : _speedLimitMB,
                    ),
                  ),
          child: Text('下载 $selectedCount 个'),
        ),
      ],
    );
  }
}
