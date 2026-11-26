import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_hub_flutter/bili/data_migration.dart';

void main() {
  late Directory root;
  late Directory target;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('vpm-migrate-');
    target = Directory('${root.path}${Platform.pathSeparator}com.videohub'
        '${Platform.pathSeparator}VideoProMax');
    await target.create(recursive: true);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> writeLegacy(String dirName, String name, String content) async {
    final dir = Directory(
      '${root.path}${Platform.pathSeparator}com.videohub'
      '${Platform.pathSeparator}$dirName',
    );
    await dir.create(recursive: true);
    await File('${dir.path}${Platform.pathSeparator}$name').writeAsString(content);
  }

  File targetFile(String name) =>
      File('${target.path}${Platform.pathSeparator}$name');

  test('旧目录数据搬进新目录，源目录保留', () async {
    await writeLegacy('video_hub_flutter', 'history.json', '[{"key":"BV1"}]');
    await writeLegacy('video_hub_flutter', 'prefs.json', '{"theme":"dark"}');
    await writeLegacy('video_hub_flutter', 'unknown.txt', 'ignored');

    await migrateLegacyData(targetDir: target.path);

    expect(await targetFile('history.json').readAsString(), '[{"key":"BV1"}]');
    expect(await targetFile('prefs.json').readAsString(), '{"theme":"dark"}');
    expect(await targetFile('unknown.txt').exists(), isFalse);
    expect(await targetFile('.data-migrated-rename').exists(), isTrue);
    expect(
      await File('${root.path}${Platform.pathSeparator}com.videohub'
              '${Platform.pathSeparator}video_hub_flutter'
              '${Platform.pathSeparator}history.json')
          .exists(),
      isTrue,
    );
  });

  test('新目录已有不同内容时先备份再覆盖', () async {
    await writeLegacy('video_hub_flutter', 'history.json', 'old');
    await targetFile('history.json').writeAsString('new');

    await migrateLegacyData(targetDir: target.path);

    expect(await targetFile('history.json').readAsString(), 'old');
    expect(await targetFile('history.json.bak').readAsString(), 'new');
  });

  test('只搬一次，之后不覆盖用户新产生的数据', () async {
    await writeLegacy('video_hub_flutter', 'history.json', 'old');
    await migrateLegacyData(targetDir: target.path);

    await targetFile('history.json').writeAsString('changed');
    await migrateLegacyData(targetDir: target.path);

    expect(await targetFile('history.json').readAsString(), 'changed');
  });

  test('多个旧目录时按列表顺序取第一个，不被后面的覆盖', () async {
    await writeLegacy('video_hub_flutter', 'history.json', 'primary');
    await writeLegacy('Video Pro Max', 'history.json', 'secondary');

    await migrateLegacyData(targetDir: target.path);

    expect(await targetFile('history.json').readAsString(), 'primary');
  });
}