// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

import '../player/playback_plan.dart';
import 'video_ref.dart';

class SourceCapabilities {
  final bool search;
  final bool recommendations;
  final bool comments;
  final bool danmaku;
  final bool episodes;
  final bool downloads;
  final bool login;
  final bool cloudHistory;
  final bool creatorSpace;

  const SourceCapabilities({
    this.search = false,
    this.recommendations = false,
    this.comments = false,
    this.danmaku = false,
    this.episodes = false,
    this.downloads = false,
    this.login = false,
    this.cloudHistory = false,
    this.creatorSpace = false,
  });

  static const bilibili = SourceCapabilities(
    search: true,
    recommendations: true,
    comments: true,
    danmaku: true,
    episodes: true,
    downloads: true,
    login: true,
    cloudHistory: true,
    creatorSpace: true,
  );
}

class VideoSummary {
  final VideoRef ref;
  final String title;
  final String author;
  final String coverUrl;
  final int durationSeconds;
  final int publishedAtSeconds;
  final int viewCount;
  final String? subtitle;
  final String creatorId;
  final String creatorAvatarUrl;

  const VideoSummary({
    required this.ref,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.durationSeconds,
    required this.publishedAtSeconds,
    required this.viewCount,
    this.subtitle,
    this.creatorId = '',
    this.creatorAvatarUrl = '',
  });
}

class VideoPart {
  final VideoRef ref;
  final String title;
  final int durationSeconds;
  final int index;
  final String? sectionTitle;

  const VideoPart({
    required this.ref,
    required this.title,
    required this.durationSeconds,
    required this.index,
    this.sectionTitle,
  });
}

class VideoDetails {
  final VideoRef ref;
  final String title;
  final String description;
  final String author;
  final String creatorId;
  final String creatorAvatarUrl;
  final List<VideoPart> parts;
  final String? collectionTitle;
  final List<VideoPart> collection;

  const VideoDetails({
    required this.ref,
    required this.title,
    required this.description,
    required this.author,
    required this.creatorId,
    required this.creatorAvatarUrl,
    this.parts = const [],
    this.collectionTitle,
    this.collection = const [],
  });
}

class VideoQuery {
  final String keyword;
  final int page;
  final String order;
  final int durationSeconds;
  final String? categoryId;

  const VideoQuery({
    required this.keyword,
    this.page = 1,
    this.order = 'totalrank',
    this.durationSeconds = 0,
    this.categoryId,
  });
}

abstract interface class VideoSource {
  String get id;
  VideoPlatform get platform;
  SourceCapabilities get capabilities;

  Future<List<VideoSummary>> search(VideoQuery query);
  Future<List<VideoSummary>> recommendations({int page = 1});
  Future<VideoDetails> details(VideoRef ref);
  Future<PlaybackPlan> playback(VideoRef ref);
}
