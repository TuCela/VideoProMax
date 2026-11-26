// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 应用改名后（显示名 `Video Pro Max`、可执行文件 `VideoProMax.exe`），
/// `path_provider` 给出的应用数据目录会随 exe 版本信息里的
/// CompanyName / ProductName 变化，用户会看到"登录态、历史、下载记录都没了"。
///
/// 这里在启动时把旧目录的数据一次性搬到新目录：
/// - 只复制，不删除源目录，随时可以回退；
/// - 目标目录已有同名文件且内容不同时，先改名成 `<name>.bak` 再覆盖；
/// - 成功后写标记文件，之后启动不再重复搬。
const _legacyDirNames = <String>['video_hub_flutter', 'Video Pro Max'];

const _markerName = '.data-migrated-rename';

const _dataFileNames = <String>[
  'prefs.json',
  'bilibili-auth.json',
  'history.json',
  'downloads.json',
];

/// [targetDir] 仅用于测试注入；运行时传 null，取自 `getApplicationSupportDirectory()`。
Future<void> migrateLegacyData({String? targetDir}) async {
  try {
    final String target =
        targetDir ?? (await getApplicationSupportDirectory()).path;
    final targetDirectory = Directory(target);
    final sep = Platform.pathSeparator;
    final marker = File('${targetDirectory.path}${sep}$_markerName');
    if (await marker.exists()) return;

    final parent = targetDirectory.parent;
    if (!await parent.exists()) return;

    final migrated = <String>[];
    final provided = <String>{};

    for (final legacyName in _legacyDirNames) {
      final source = Directory('${parent.path}$sep$legacyName');
      if (!await source.exists()) continue;
      if (source.absolute.path == targetDirectory.absolute.path) continue;

      await for (final entity in source.list(followLinks: false)) {
        if (entity is! File) continue;
        final fileName = entity.uri.pathSegments.last;
        if (!_dataFileNames.contains(fileName)) continue;
        if (provided.contains(fileName)) continue;

        await targetDirectory.create(recursive: true);
        final dest = File('${targetDirectory.path}$sep$fileName');

        if (await dest.exists()) {
          if (await _sameContent(entity, dest)) {
            provided.add(fileName);
            continue;
          }
          await dest.rename(await _freeBackupPath(dest.path));
        }

        await entity.copy(dest.path);
        provided.add(fileName);
        migrated.add(fileName);
      }
    }

    await targetDirectory.create(recursive: true);
    await marker.writeAsString(
      'migrated=${migrated.join(',')}\n'
      'time=${DateTime.now().toIso8601String()}\n',
    );
  } catch (_) {
    // 搬迁失败不能挡住启动：数据仍在旧目录，用户可手动拷贝。
  }
}

Future<String> _freeBackupPath(String path) async {
  var candidate = '$path.bak';
  var index = 1;
  while (await File(candidate).exists()) {
    candidate = '$path.bak$index';
    index++;
  }
  return candidate;
}

Future<bool> _sameContent(File a, File b) async {
  if (await a.length() != await b.length()) return false;
  final left = await a.readAsBytes();
  final right = await b.readAsBytes();
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}