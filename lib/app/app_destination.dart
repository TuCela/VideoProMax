// Copyright (c) 2026 flysky
// SPDX-License-Identifier: GPL-3.0-only

enum AppDestination { home, history, downloads, space, settings }

extension AppDestinationLabel on AppDestination {
  String get label => switch (this) {
    AppDestination.home => '主页',
    AppDestination.history => '历史',
    AppDestination.downloads => '下载',
    AppDestination.space => 'UP空间',
    AppDestination.settings => '设置',
  };
}
