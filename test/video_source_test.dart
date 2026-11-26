// Copyright (c) 2026 flysky
// SPDX-License-Identifier: GPL-3.0-only

import 'package:flutter_test/flutter_test.dart';
import 'package:video_hub_flutter/core/video_ref.dart';
import 'package:video_hub_flutter/core/video_source.dart';
import 'package:video_hub_flutter/player/playback_plan.dart';

void main() {
  test('VideoRef keeps platform and part identity', () {
    const bili = VideoRef(
      platform: VideoPlatform.bilibili,
      videoId: 'BV1Pq4y1b7fp',
      partId: '123',
    );
    const youtube = VideoRef(
      platform: VideoPlatform.youtube,
      videoId: 'BV1Pq4y1b7fp',
      partId: '123',
    );

    expect(bili.key, 'bilibili:BV1Pq4y1b7fp:123');
    expect(bili, isNot(youtube));
    expect(bili.copyWith(), bili);
  });

  test('Bilibili capabilities are explicit', () {
    const capabilities = SourceCapabilities.bilibili;
    expect(capabilities.search, isTrue);
    expect(capabilities.danmaku, isTrue);
    expect(capabilities.downloads, isTrue);
    expect(capabilities.creatorSpace, isTrue);
  });

  test('PlaybackPlan separates video and audio tracks', () {
    const ref = VideoRef(
      platform: VideoPlatform.bilibili,
      videoId: 'BV1Pq4y1b7fp',
    );
    const plan = PlaybackPlan(
      ref: ref,
      kind: PlaybackKind.nativeDash,
      tracks: [
        MediaTrack(url: 'video', kind: MediaTrackKind.video),
        MediaTrack(url: 'audio', kind: MediaTrackKind.audio),
      ],
    );

    expect(plan.videoTracks.single.url, 'video');
    expect(plan.audioTracks.single.url, 'audio');
  });
}
