// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../bili/prefs.dart';

/// 网络代理设置。
///
/// YouTube 与 B站在国内的可达性完全不同：前者通常必须走代理，而代理软件
/// 往往只改系统代理（注册表）或环境变量，Dart 的 HttpClient、yt-dlp 和
/// mpv 都不会自动继承。这里统一解析出一份代理地址，三个使用者共用。
class ProxySettings {
  ProxySettings._();

  static final ProxySettings instance = ProxySettings._();

  static const String modeSystem = 'system';
  static const String modeManual = 'manual';
  static const String modeDirect = 'direct';

  /// 当前生效的代理地址，空字符串表示直连。
  final ValueNotifier<String> current = ValueNotifier<String>('');

  String mode = modeSystem;
  String manual = '';

  /// 从 prefs 恢复配置并解析一次。
  Future<void> load(AppPrefs prefs) async {
    mode = prefs.proxyMode;
    manual = prefs.proxyUrl;
    await refresh();
  }

  /// 重新解析代理地址（切换模式 / 手动地址 / 打开设置页时调用）。
  Future<String> refresh() async {
    var value = '';
    switch (mode) {
      case modeManual:
        value = _normalize(manual);
      case modeDirect:
        value = '';
      default:
        // Windows 上以「系统代理」为准：环境变量常常是终端/工具注入的，
        // 不一定和用户在系统设置里配的代理一致。
        value = await _fromWindowsRegistry();
        if (value.isEmpty) value = _fromEnvironment();
    }
    if (current.value != value) current.value = value;
    return value;
  }

  Future<void> apply(AppPrefs prefs, {String? mode, String? manual}) async {
    if (mode != null) this.mode = mode;
    if (manual != null) this.manual = manual;
    prefs.proxyMode = this.mode;
    prefs.proxyUrl = this.manual;
    await prefs.save();
    await refresh();
  }

  /// yt-dlp 参数：始终显式传给子进程，避免它去读环境变量里的沙箱代理。
  List<String> get ytDlpArgs => ['--proxy', current.value];

  /// mpv 的 http-proxy。空字符串表示不使用代理。
  String get mpvProxy => current.value;

  String _fromEnvironment() {
    for (final key in const [
      'HTTPS_PROXY',
      'https_proxy',
      'HTTP_PROXY',
      'http_proxy',
      'ALL_PROXY',
      'all_proxy',
    ]) {
      final value = _normalize(Platform.environment[key] ?? '');
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static const String _internetSettings =
      r'Software\Microsoft\Windows\CurrentVersion\Internet Settings';
  static const int _hkeyCurrentUser = 0x80000001;
  static const int _rrfRtRegSz = 0x00000002;

  /// RRF_RT_ANY：不限定类型。读 ProxyEnable 时用 DWORD 类型限定在部分
  /// 系统上会返回 1630，改成任意类型再按 4 字节解释。
  static const int _rrfRtAny = 0x0000FFFF;

  Future<String> _fromWindowsRegistry() async {
    if (!Platform.isWindows) return '';
    try {
      // 不走 reg.exe：子进程在部分安全策略下会被拦，而且杀软对 spawn
      // 注册表查询比较敏感。
      final raw = (_readRegistryString(_internetSettings, 'ProxyServer') ?? '')
          .trim();
      if (raw.isEmpty) return '';
      // 明确关闭代理（ProxyEnable=0）时才直连；读不到就按已开启处理。
      final enabled = _readRegistryDword(_internetSettings, 'ProxyEnable');
      if (enabled == 0) return '';
      // 可能是 "127.0.0.1:8080"，也可能是 "http=...;https=...;socks=..."。
      if (raw.contains('=')) {
        final parts = <String, String>{};
        for (final item in raw.split(';')) {
          final index = item.indexOf('=');
          if (index <= 0) continue;
          parts[item.substring(0, index).toLowerCase()] =
              item.substring(index + 1);
        }
        return _normalize(parts['https'] ?? parts['http'] ?? '');
      }
      return _normalize(raw);
    } catch (_) {
      return '';
    }
  }

  String? _readRegistryString(String subKey, String valueName) {
    final advapi = DynamicLibrary.open('advapi32.dll');
    final regGetValue = advapi.lookupFunction<
        Int32 Function(
          IntPtr,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Uint32,
          Pointer<Uint32>,
          Pointer<Uint8>,
          Pointer<Uint32>,
        ),
        int Function(
          int,
          Pointer<Utf16>,
          Pointer<Utf16>,
          int,
          Pointer<Uint32>,
          Pointer<Uint8>,
          Pointer<Uint32>,
        )>('RegGetValueW');
    final key = subKey.toNativeUtf16();
    final name = valueName.toNativeUtf16();
    final type = calloc<Uint32>();
    final size = calloc<Uint32>()..value = 4096;
    final buffer = calloc<Uint8>(size.value);
    try {
      final code = regGetValue(
        _hkeyCurrentUser,
        key,
        name,
        _rrfRtRegSz,
        type,
        buffer,
        size,
      );
      if (code != 0) return null;
      return buffer.cast<Utf16>().toDartString();
    } finally {
      calloc.free(key);
      calloc.free(name);
      calloc.free(type);
      calloc.free(size);
      calloc.free(buffer);
    }
  }

  int? _readRegistryDword(String subKey, String valueName) {
    final advapi = DynamicLibrary.open('advapi32.dll');
    final regGetValue = advapi.lookupFunction<
        Int32 Function(
          IntPtr,
          Pointer<Utf16>,
          Pointer<Utf16>,
          Uint32,
          Pointer<Uint32>,
          Pointer<Uint8>,
          Pointer<Uint32>,
        ),
        int Function(
          int,
          Pointer<Utf16>,
          Pointer<Utf16>,
          int,
          Pointer<Uint32>,
          Pointer<Uint8>,
          Pointer<Uint32>,
        )>('RegGetValueW');
    final key = subKey.toNativeUtf16();
    final name = valueName.toNativeUtf16();
    final type = calloc<Uint32>();
    final size = calloc<Uint32>()..value = 8;
    final data = calloc<Uint8>(8);
    try {
      final code = regGetValue(
        _hkeyCurrentUser,
        key,
        name,
        _rrfRtAny,
        type,
        data,
        size,
      );
      if (code != 0) return null;
      return data.cast<Uint32>().value;
    } finally {
      calloc.free(key);
      calloc.free(name);
      calloc.free(type);
      calloc.free(size);
      calloc.free(data);
    }
  }

  /// 补全协议前缀。注册表里通常只有 host:port，默认按 HTTP 代理处理。
  String _normalize(String value) {
    var text = value.trim();
    if (text.isEmpty) return '';
    if (!text.contains('://')) text = 'http://$text';
    if (text.endsWith('/')) text = text.substring(0, text.length - 1);
    return text;
  }
}
