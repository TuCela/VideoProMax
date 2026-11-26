import '../core/video_ref.dart';

enum PlaybackKind { nativeDash, progressive, embedded }

enum MediaTrackKind { video, audio }

class MediaTrack {
  final String url;
  final MediaTrackKind kind;
  final String? mimeType;
  final String? label;
  final int width;
  final int height;
  final int bandwidth;
  final List<String> backupUrls;

  const MediaTrack({
    required this.url,
    required this.kind,
    this.mimeType,
    this.label,
    this.width = 0,
    this.height = 0,
    this.bandwidth = 0,
    this.backupUrls = const [],
  });
}

class PlaybackPlan {
  final VideoRef ref;
  final PlaybackKind kind;
  final List<MediaTrack> tracks;
  final Map<String, String> headers;
  final int durationSeconds;
  final String? embeddedUrl;

  const PlaybackPlan({
    required this.ref,
    required this.kind,
    this.tracks = const [],
    this.headers = const {},
    this.durationSeconds = 0,
    this.embeddedUrl,
  });

  List<MediaTrack> get videoTracks =>
      tracks.where((track) => track.kind == MediaTrackKind.video).toList();

  List<MediaTrack> get audioTracks =>
      tracks.where((track) => track.kind == MediaTrackKind.audio).toList();
}
