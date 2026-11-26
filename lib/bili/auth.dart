// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import 'client.dart';
import 'models.dart';

const _generateUrl =
    'https://passport.bilibili.com/x/passport-login/web/qrcode/generate';
const _pollUrl =
    'https://passport.bilibili.com/x/passport-login/web/qrcode/poll';
const _navUrl = 'https://api.bilibili.com/x/web-interface/nav';
const _passportReferer = 'https://passport.bilibili.com/';

class QrSession {
  final String key;
  final String url;

  const QrSession({required this.key, required this.url});
}

enum QrStatus { waiting, scanned, success, expired, error }

class QrPollResult {
  final QrStatus status;
  final String? message;

  const QrPollResult(this.status, [this.message]);
}

/// 扫码登录 + 凭证本地保存
class BiliAuth {
  BiliAuth(this.client);

  final BiliClient client;
  Map<String, String> _cookies = {};
  BiliUser? user;
  File? _file;

  bool get isLoggedIn => _cookies.containsKey('SESSDATA');

  String _serialize(Map<String, String> cookies) =>
      cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Future<void> load() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}bilibili-auth.json');
      _file = file;
      if (!await file.exists()) return;
      final raw = jsonDecode(await file.readAsString());
      if (raw is! Map) return;
      final cookies = (raw['cookies'] as Map?)?.cast<String, String>() ?? {};
      if (!cookies.containsKey('SESSDATA')) return;
      _cookies = cookies;
      client.loginCookie = _serialize(cookies);
      final u = raw['user'];
      if (u is Map) {
        user = BiliUser(
          name: u['name'] as String? ?? 'B站用户',
          mid: u['mid'] as String? ?? '',
          avatar: u['avatar'] as String? ?? '',
        );
      } else {
        await _refreshUser();
      }
    } catch (_) {
      // 凭证损坏就当未登录
    }
  }

  Future<QrSession> startLogin() async {
    final res = await clientHeaderDio().get(
      _generateUrl,
      options: Options(headers: {...kBrowserHeaders, 'Referer': _passportReferer}),
    );
    final data = res.data['data'];
    final key = data?['qrcode_key'] as String?;
    final url = data?['url'] as String?;
    if (key == null || url == null) {
      throw Exception('获取二维码失败 code=${res.data['code']}');
    }
    return QrSession(key: key, url: url);
  }

  Future<QrPollResult> poll(QrSession session) async {
    final res = await clientHeaderDio().get(
      _pollUrl,
      queryParameters: {'qrcode_key': session.key},
      options: Options(headers: {...kBrowserHeaders, 'Referer': _passportReferer}),
    );
    final data = res.data['data'];
    final code = (data?['code'] as num?)?.toInt();
    if (code == 0) {
      final jar = <String, String>{};
      _collectSetCookies(res.headers.map['set-cookie'] ?? const [], jar);
      if (!jar.containsKey('SESSDATA')) {
        await _fallbackCallback(data?['url'] as String?, jar);
      }
      if (!jar.containsKey('SESSDATA')) {
        return const QrPollResult(QrStatus.error, '登录成功但没拿到 SESSDATA，请重试');
      }
      _cookies = jar;
      client.loginCookie = _serialize(jar);
      await _refreshUser();
      await _persist();
      return const QrPollResult(QrStatus.success);
    }
    switch (code) {
      case 86101:
        return const QrPollResult(QrStatus.waiting);
      case 86090:
        return const QrPollResult(QrStatus.scanned, '已扫码，请在手机上确认');
      case 86038:
        return const QrPollResult(QrStatus.expired, '二维码已过期，请重新获取');
      default:
        return QrPollResult(QrStatus.error, '登录状态异常（$code）');
    }
  }

  void _collectSetCookies(List<String> lines, Map<String, String> jar) {
    for (final line in lines) {
      // 一条里可能塞了多个 cookie，用逗号切（避开 Expires 里的逗号）
      for (final part in line.split(RegExp(r',(?=\s*[^;,=]+\s*=)'))) {
        final pair = part.split(';').first;
        final eq = pair.indexOf('=');
        if (eq > 0) {
          jar[pair.substring(0, eq).trim()] = pair.substring(eq + 1).trim();
        }
      }
    }
  }

  Future<void> _fallbackCallback(String? url, Map<String, String> jar) async {
    if (url == null || url.isEmpty) return;
    try {
      final res = await clientHeaderDio().get(
        url,
        options: Options(
          headers: {...kBrowserHeaders, 'Referer': 'https://www.bilibili.com/'},
        ),
      );
      _collectSetCookies(res.headers.map['set-cookie'] ?? const [], jar);
    } catch (_) {
      // 兜底失败就按失败处理
    }
  }

  Future<void> _refreshUser() async {
    try {
      final res = await clientHeaderDio().get(
        _navUrl,
        options: Options(headers: {
          ...kBrowserHeaders,
          if (client.loginCookie.isNotEmpty) 'Cookie': client.loginCookie,
        }),
      );
      final data = res.data['data'];
      if (data is Map && data['uname'] != null) {
        user = BiliUser(
          name: data['uname'] as String? ?? 'B站用户',
          mid: (data['mid'] ?? '').toString(),
          avatar: data['face'] as String? ?? '',
        );
      }
    } catch (_) {
      // 用户信息拿不到不影响登录态
    }
  }

  Future<void> _persist() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = _file ??
          File('${dir.path}${Platform.pathSeparator}bilibili-auth.json');
      _file = file;
      await file.writeAsString(jsonEncode({
        'cookies': _cookies,
        'user': {
          'name': user?.name ?? 'B站用户',
          'mid': user?.mid ?? '',
          'avatar': user?.avatar ?? '',
        },
      }));
    } catch (_) {
      // 保存失败只影响下次启动免登录
    }
  }

  Future<void> logout() async {
    _cookies = {};
    user = null;
    client.loginCookie = '';
    try {
      await _file?.writeAsString('{}');
    } catch (_) {}
  }

  /// 登录相关请求用的独立 Dio（避免基类的 Cookie 干扰 Set-Cookie 读取）
  Dio clientHeaderDio() => Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 12),
        validateStatus: (status) => status != null && status < 500,
      ));
}
