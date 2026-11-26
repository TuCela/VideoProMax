// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 播放器上方的可编辑链接条。
///
/// 平时显示当前视频的 B站网页地址（本地文件显示本地路径），
/// 用户粘贴网址后按回车即可直接播放；右侧保留复制按钮。
class PlayUrlBar extends StatefulWidget {
  const PlayUrlBar({
    super.key,
    required this.url,
    this.label = '网页链接',
    this.leading,
    this.onPlayUrl,
  });

  /// 当前链接（网页版或本地路径）。
  final String url;
  final String label;

  /// 可选的左侧按钮（收起搜索结果后显示的「展开」）。
  final Widget? leading;

  /// 回车提交网址的回调。传入用户输入的原始文本，由页面负责解析播放。
  final ValueChanged<String>? onPlayUrl;

  @override
  State<PlayUrlBar> createState() => _PlayUrlBarState();
}

class _PlayUrlBarState extends State<PlayUrlBar> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.url);
  }

  @override
  void didUpdateWidget(PlayUrlBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 播放了新视频时同步显示新链接；用户正在输入则不要覆盖。
    if (widget.url != oldWidget.url && !_focus.hasFocus) {
      _controller.text = widget.url;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    widget.onPlayUrl?.call(text);
    _focus.unfocus();
  }

  void _copy() {
    final text = _controller.text.trim().isNotEmpty
        ? _controller.text.trim()
        : widget.url;
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('播放链接已复制到剪贴板')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(widget.leading == null ? 16 : 8, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF23262D)),
      ),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 16,
              color: const Color(0xFF2A2E36),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(Icons.link, size: 14, color: Color(0xFF7C93FF)),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF8B9099)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onSubmitted: _submit,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFB8BEC8),
                fontFamily: 'Consolas',
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '粘贴 B 站视频链接，回车播放',
                hintStyle: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6E7480),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _copy,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.copy_all_outlined,
                    size: 13, color: Color(0xFF7C93FF)),
                SizedBox(width: 4),
                Text(
                  '复制',
                  style: TextStyle(fontSize: 11, color: Color(0xFF7C93FF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
