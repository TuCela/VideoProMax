// Copyright (c) 2026 flysky
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app_shell.dart';
import 'ui/font_settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const VideoHubApp());
}

class VideoHubApp extends StatelessWidget {
  const VideoHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B8CFF),
      brightness: Brightness.dark,
    );
    return ValueListenableBuilder<int>(
      valueListenable: FontSettings.instance.delta,
      builder: (_, __, ___) {
        return MaterialApp(
          title: 'VideoHub',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: scheme,
            scaffoldBackgroundColor: const Color(0xFF0E1117),
            cardColor: const Color(0xFF141820),
            dividerColor: const Color(0xFF2A313E),
            visualDensity: VisualDensity.compact,
            // 固定中文字体族：Windows 默认会按字符逐个回退，
            // 个别汉字会落到宋体，导致同一行标题里出现两种字形。
            fontFamily: 'Microsoft YaHei UI',
            fontFamilyFallback: const [
              'Microsoft YaHei',
              'Deng',
              'Segoe UI',
              'Arial',
            ],
          ),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(FontSettings.instance.scaler),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const AppShell(),
        );
      },
    );
  }
}
