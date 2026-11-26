// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app/proxy_settings.dart';

class YtDlpException implements Exception {
  YtDlpException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// yt-dlp 子进程封装。
///
/// YouTube 的播放地址需要解 n-sig（YouTube 会对未签名的链接限速到约
/// 250KB/s），这一步要 JS 运行时执行挑战脚本，所以随包带 deno.exe，
/// 并在每次调用时显式指定，避免依赖用户环境。
class YtDlp {
  YtDlp._();

  static final YtDlp instance = YtDlp._();

  String? _exe;
  String? _deno;
  bool _inited = false;

  bool get available => _exe != null;

  /// 解析可执行文件位置。发布包放在 exe 同级，开发机在 windows/tools。
  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    _exe = await _locate('yt-dlp.exe');
    _deno = await _locate('deno.exe');
  }

  Future<String?> _locate(String name) async {
    final dirs = <String>[
      File(Platform.resolvedExecutable).parent.path,
      '${Directory.current.path}\\windows\\tools',
      '${Directory.current.path}\\tools',
    ];
    for (final dir in dirs) {
      final file = File('$dir\\$name');
      if (file.existsSync()) return file.path;
    }
    try {
      final result = await Process.run('where', [name]);
      if (result.exitCode == 0) {
        for (final line in '${result.stdout}'.split(RegExp(r'\r?\n'))) {
          final text = line.trim();
          if (text.isNotEmpty) return text;
        }
      }
    } catch (_) {}
    return null;
  }

  List<String> _baseArgs() => [
    '--ignore-config',
    '--no-warnings',
    '--no-progress',
    // 有新版本时才提示，不阻塞输出。
    '--no-check-formats',
    if (_deno != null) ...['--js-runtimes', 'deno:$_deno'],
    // 始终显式指定：没有代理时传空串，避免子进程继承到不可用的环境代理。
    ...ProxySettings.instance.ytDlpArgs,
  ];

  /// 取 JSON 元数据。[extra] 追加在输入地址之前。
  Future<Map<String, dynamic>> json(
    String target, {
    List<String> extra = const [],
    Duration timeout = const Duration(seconds: 90),
  }) async {
    await init();
    final exe = _exe;
    if (exe == null) {
      throw YtDlpException('未找到 yt-dlp.exe，请确认安装包完整');
    }
    final result = await _run(
      exe,
      [..._baseArgs(), ...extra, '-J', target],
      timeout: timeout,
    );
    if (result.exitCode != 0) {
      throw YtDlpException(_humanError(result.stderr));
    }
    final text = result.stdout.trim();
    final start = text.indexOf('{');
    if (start < 0) {
      throw YtDlpException('yt-dlp 返回内容无法解析');
    }
    try {
      return jsonDecode(text.substring(start)) as Map<String, dynamic>;
    } catch (_) {
      throw YtDlpException('yt-dlp 返回的 JSON 解析失败');
    }
  }

  /// 直接下载（下载功能使用），返回进程句柄以便调用方读取进度。
  Future<Process> startDownload(List<String> args) async {
    await init();
    final exe = _exe;
    if (exe == null) {
      throw YtDlpException('未找到 yt-dlp.exe，请确认安装包完整');
    }
    return Process.start(exe, [
      ..._baseArgs(),
      '--newline',
      '--no-part',
      ...args,
    ]);
  }

  Future<_RunResult> _run(
    String exe,
    List<String> args, {
    required Duration timeout,
  }) async {
    final process = await Process.start(exe, args);
    final out = StringBuffer();
    final err = StringBuffer();
    final outDone = process.stdout
        .transform(utf8.decoder)
        .listen(out.write)
        .asFuture<void>();
    final errDone = process.stderr
        .transform(utf8.decoder)
        .listen(err.write)
        .asFuture<void>();
    var code = -1;
    try {
      code = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill();
      throw YtDlpException('yt-dlp 超过 ${timeout.inSeconds} 秒没有响应');
    }
    await Future.wait([outDone, errDone]);
    return _RunResult(code, out.toString(), err.toString());
  }

  /// yt-dlp 的报错很长，取最后几行有意义的内容。
  String _humanError(String stderr) {
    final lines = stderr
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('WARNING'))
        .toList();
    if (lines.isEmpty) return 'yt-dlp 执行失败';
    final text = lines.last;
    if (text.contains('Unable to connect to proxy') ||
        text.contains('Tunnel connection failed')) {
      return '代理连接失败，请检查设置里的代理地址';
    }
    if (text.contains('Sign in to confirm')) {
      return '该视频需要登录才能观看';
    }
    return text.length > 160 ? '${text.substring(0, 160)}…' : text;
  }
}

class _RunResult {
  _RunResult(this.exitCode, this.stdout, this.stderr);

  final int exitCode;
  final String stdout;
  final String stderr;
}
