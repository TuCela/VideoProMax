import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../bili/auth.dart';

/// 扫码登录弹窗：拿二维码 -> 每 2 秒轮询 -> 成功返回 true
class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key, required this.auth});

  final BiliAuth auth;

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  QrSession? _session;
  String _status = '正在获取二维码…';
  bool _done = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final session = await widget.auth.startLogin();
      if (!mounted) return;
      setState(() {
        _session = session;
        _status = '请用 B站 App 扫码';
      });
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = '获取二维码失败：$error');
    }
  }

  Future<void> _poll() async {
    final session = _session;
    if (session == null || _done) return;
    try {
      final result = await widget.auth.poll(session);
      if (!mounted) return;
      switch (result.status) {
        case QrStatus.success:
          _done = true;
          _timer?.cancel();
          Navigator.of(context).pop(true);
        case QrStatus.expired:
          _timer?.cancel();
          setState(() => _status = result.message ?? '二维码已过期');
        case QrStatus.scanned:
          setState(() => _status = result.message ?? '已扫码，请在手机上确认');
        case QrStatus.waiting:
        case QrStatus.error:
          if (result.message != null) setState(() => _status = result.message!);
      }
    } catch (_) {
      // 网络抖动不打断轮询
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('登录 B站'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _session == null
                  ? const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : QrImageView(
                      data: _session!.url,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
            ),
            const SizedBox(height: 16),
            Text(_status, textAlign: TextAlign.center),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
