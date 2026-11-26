import 'package:flutter_test/flutter_test.dart';
import 'package:video_hub_flutter/bili/download_store.dart';
import 'package:video_hub_flutter/bili/history.dart';

void main() {
  test('legacy history JSON keeps Bilibili identity', () {
    final entry = HistoryEntry.fromJson({
      'key': 'v:BV1Pq4y1b7fp:123',
      'kind': 'video',
      'bvid': 'BV1Pq4y1b7fp',
      'cid': '123',
      'title': 'test',
      'partTitle': '',
      'cover': '',
      'positionSeconds': 10,
      'durationSeconds': 100,
      'updatedAt': 1,
    });

    expect(entry.platform, 'bilibili');
    expect(entry.videoId, isEmpty);
    expect(entry.toJson()['platform'], 'bilibili');
  });

  test('legacy download JSON keeps Bilibili identity', () {
    final record = DownloadRecord.fromJson({
      'key': 'v:BV1Pq4y1b7fp:123',
      'bvid': 'BV1Pq4y1b7fp',
      'cid': '123',
      'title': 'test',
      'qualityId': 80,
      'qualityLabel': '1080P',
      'status': 'done',
      'createdAt': 1,
    });

    expect(record.platform, 'bilibili');
    expect(record.videoId, isEmpty);
    expect(record.toJson()['platform'], 'bilibili');
  });

  test('new records preserve platform identity', () {
    final entry = HistoryEntry(
      key: 'youtube:abc:',
      kind: 'video',
      platform: 'youtube',
      videoId: 'abc',
      bvid: '',
      cid: '',
      title: 'test',
      partTitle: '',
      cover: '',
      positionSeconds: 0,
      durationSeconds: 100,
      updatedAt: 1,
    );
    final restored = HistoryEntry.fromJson(entry.toJson());

    expect(restored.platform, 'youtube');
    expect(restored.videoId, 'abc');
  });
}
