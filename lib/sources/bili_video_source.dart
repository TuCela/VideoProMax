// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import '../bili/client.dart';
import '../bili/models.dart';
import '../core/video_ref.dart';
import '../core/video_source.dart';
import '../player/playback_plan.dart';

class BiliVideoSource implements VideoSource {
  final BiliClient client;

  const BiliVideoSource(this.client);

  @override
  String get id => 'bilibili';

  @override
  VideoPlatform get platform => VideoPlatform.bilibili;

  @override
  SourceCapabilities get capabilities => SourceCapabilities.bilibili;

  VideoRef _ref(String bvid, [String? cid]) =>
      VideoRef(platform: platform, videoId: bvid, partId: cid);

  VideoSummary _summary(VideoItem item) => VideoSummary(
    ref: _ref(item.bvid),
    title: item.title,
    author: item.author,
    coverUrl: item.cover,
    durationSeconds: item.durationSeconds,
    publishedAtSeconds: item.pubdate,
    viewCount: item.play,
    subtitle: item.subtitle,
    creatorId: item.mid.toString(),
    creatorAvatarUrl: item.face,
  );

  @override
  Future<List<VideoSummary>> search(VideoQuery query) async {
    final duration = switch (query.durationSeconds) {
      <= 60 => 1,
      <= 240 => 2,
      <= 600 => 3,
      > 600 => 4,
      _ => 0,
    };
    final items = await client.search(
      query.keyword,
      page: query.page,
      order: query.order,
      duration: duration,
      tids: int.tryParse(query.categoryId ?? '') ?? 0,
    );
    return items.map(_summary).toList();
  }

  @override
  Future<List<VideoSummary>> recommendations({int page = 1}) async {
    final items = await client.fetchRecommend(freshIdx: page);
    return items.map(_summary).toList();
  }

  @override
  Future<VideoDetails> details(VideoRef ref) async {
    final detail = await client.fetchDetail(ref.videoId);
    return VideoDetails(
      ref: ref.copyWith(partId: detail.cid),
      title: detail.title,
      description: detail.description,
      author: '',
      creatorId: detail.ownerMid.toString(),
      creatorAvatarUrl: detail.ownerFace,
      parts: [
        for (var i = 0; i < detail.pages.length; i++)
          VideoPart(
            ref: _ref(ref.videoId, detail.pages[i].cid),
            title: detail.pages[i].title,
            durationSeconds: detail.pages[i].durationSeconds,
            index: detail.pages[i].page,
          ),
      ],
      collectionTitle: detail.seasonTitle,
      collection: [
        for (var i = 0; i < detail.episodes.length; i++)
          VideoPart(
            ref: _ref(detail.episodes[i].bvid, detail.episodes[i].cid),
            title: detail.episodes[i].title,
            durationSeconds: detail.episodes[i].durationSeconds,
            index: i + 1,
            sectionTitle: detail.episodes[i].sectionTitle,
          ),
      ],
    );
  }

  @override
  Future<PlaybackPlan> playback(VideoRef ref) async {
    final resolved = await client.resolve(ref.videoId, cid: ref.partId);
    return PlaybackPlan(
      ref: ref.copyWith(partId: resolved.cid),
      kind: PlaybackKind.nativeDash,
      durationSeconds: resolved.durationSeconds,
      headers: client.streamHeaders,
      tracks: [
        for (final stream in resolved.videos)
          MediaTrack(
            url: stream.baseUrl,
            kind: MediaTrackKind.video,
            mimeType: stream.codecs,
            label: stream.label,
            width: stream.width,
            height: stream.height,
            bandwidth: stream.bandwidth,
            backupUrls: stream.backupUrls,
          ),
        if (resolved.audio != null)
          MediaTrack(
            url: resolved.audio!.baseUrl,
            kind: MediaTrackKind.audio,
            mimeType: resolved.audio!.codecs,
            label: resolved.audio!.label,
            bandwidth: resolved.audio!.bandwidth,
            backupUrls: resolved.audio!.backupUrls,
          ),
      ],
    );
  }
}
