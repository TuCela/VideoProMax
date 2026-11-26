// Copyright (c) 2026 flysky
// SPDX-License-Identifier: GPL-3.0-only

enum VideoPlatform { bilibili, youtube, other }

class VideoRef {
  final VideoPlatform platform;
  final String videoId;
  final String? partId;

  const VideoRef({required this.platform, required this.videoId, this.partId});

  String get key => '${platform.name}:$videoId:${partId ?? ""}';

  VideoRef copyWith({String? partId}) => VideoRef(
    platform: platform,
    videoId: videoId,
    partId: partId ?? this.partId,
  );

  @override
  bool operator ==(Object other) =>
      other is VideoRef &&
      other.platform == platform &&
      other.videoId == videoId &&
      other.partId == partId;

  @override
  int get hashCode => Object.hash(platform, videoId, partId);
}
