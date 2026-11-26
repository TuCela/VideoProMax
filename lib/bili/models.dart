// Copyright (c) 2026 TuCela
// SPDX-License-Identifier: GPL-3.0-only

/// B站相关的数据模型

class VideoItem {
  final String bvid;
  final String title;
  final String author;
  final String cover;
  final int play;
  final int durationSeconds;
  final int pubdate;

  /// 版权内容（番剧/国创/综艺）的季 id，非版权内容为 null
  final int? seasonId;

  /// 列表里的补充说明（如“全8话”），优先于作者/播放量显示
  final String? subtitle;

  /// UP 主 mid 与头像（列表接口通常带 face，部分接口只有 mid）
  final int mid;
  final String face;

  const VideoItem({
    required this.bvid,
    required this.title,
    required this.author,
    required this.cover,
    required this.play,
    required this.durationSeconds,
    required this.pubdate,
    this.seasonId,
    this.subtitle,
    this.mid = 0,
    this.face = '',
  });

  String get durationText {
    final d = Duration(seconds: durationSeconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
  }

  String get playText {
    if (play >= 10000) return '${(play / 10000).toStringAsFixed(1)} 万播放';
    return '$play 播放';
  }
}

/// 一条 DASH 流（视频或音频）
class DashStream {
  final int id;
  final String baseUrl;
  final int bandwidth;
  final String codecs;
  final int width;
  final int height;

  const DashStream({
    required this.id,
    required this.baseUrl,
    required this.bandwidth,
    required this.codecs,
    required this.width,
    required this.height,
    this.backupUrls = const [],
    this.labelOverride,
  });

  /// CDN 备用线路。主线路偶尔会给截断或极慢的流，卡住时切这里。
  final List<String> backupUrls;

  /// 画质显示名（YouTube 等非 B站源用，为空时按 B站的 qn 映射）。
  final String? labelOverride;

  String get codecName {
    if (codecs.startsWith('avc1')) return 'H.264';
    if (codecs.startsWith('hev') || codecs.startsWith('hvc1')) return 'HEVC';
    if (codecs.startsWith('av01')) return 'AV1';
    return codecs.split('.').first;
  }

  String get label => labelOverride ?? '${qualityLabel(id)} · $codecName';
}

String qualityLabel(int id) {
  const labels = {
    16: '360P',
    32: '480P',
    64: '720P',
    74: '720P60',
    80: '1080P',
    100: '智能修复',
    112: '1080P+',
    116: '1080P 高码率',
    120: '4K',
    125: 'HDR',
    126: '杜比视界',
    127: '8K',
  };
  return labels[id] ?? '画质 $id';
}

/// 视频的一个分P
class VideoPage {
  final int page;
  final String title;
  final String cid;
  final int durationSeconds;

  const VideoPage({
    required this.page,
    required this.title,
    required this.cid,
    required this.durationSeconds,
  });

  String get durationText => formatSeconds(durationSeconds);
}

/// 合集里的一个正片
class SeasonEpisode {
  final String bvid;
  final String cid;
  final String title;
  final String sectionTitle;
  final int durationSeconds;

  const SeasonEpisode({
    required this.bvid,
    required this.cid,
    required this.title,
    required this.sectionTitle,
    required this.durationSeconds,
  });

  String get durationText => formatSeconds(durationSeconds);
}

/// 视频详情：分P + 合集
class VideoDetail {
  final String cid;
  final int aid;
  final String title;
  final String description;
  final List<VideoPage> pages;
  final String? seasonTitle;
  final List<SeasonEpisode> episodes;

  /// 视频所属 UP 主（用于视频下方头像/名字跳转 UP 首页）
  final int ownerMid;
  final String ownerFace;

  const VideoDetail({
    required this.cid,
    required this.aid,
    this.title = '',
    this.description = '',
    required this.pages,
    required this.seasonTitle,
    required this.episodes,
    this.ownerMid = 0,
    this.ownerFace = '',
  });

  bool get hasPages => pages.length > 1;
  bool get hasSeason => episodes.length > 1;
}

/// 版权内容（番剧/国创/综艺）的一集
class PgcEpisode {
  final int epId;
  final int aid;
  final String bvid;
  final String cid;
  final String title;
  final String badge;
  final int durationSeconds;

  const PgcEpisode({
    required this.epId,
    required this.aid,
    required this.bvid,
    required this.cid,
    required this.title,
    required this.badge,
    required this.durationSeconds,
  });
}

/// 版权内容的一季
class PgcSeason {
  final int seasonId;
  final String title;
  final String cover;
  final String subtitle;
  final List<PgcEpisode> episodes;

  const PgcSeason({
    required this.seasonId,
    required this.title,
    required this.cover,
    required this.subtitle,
    required this.episodes,
  });

  bool get hasEpisodes => episodes.length > 1;
}

/// 一条弹幕
class DanmakuItem {
  final double time; // 出现时间（秒）
  final int mode; // 1-3 滚动，4 底部，5 顶部
  final int fontSize;
  final int color; // RGB
  final String text;

  const DanmakuItem({
    required this.time,
    required this.mode,
    required this.fontSize,
    required this.color,
    required this.text,
  });

  bool get isScroll => mode <= 3;
}

/// B站服务器上的观看记录（用于跨设备续播）
class CloudHistoryItem {
  final String kind; // video | pgc
  final String bvid;
  final String cid;
  final int? epId;
  final String title;
  final String partTitle;
  final String cover;
  final int progressSeconds;
  final int durationSeconds;
  final int viewAt;

  const CloudHistoryItem({
    required this.kind,
    required this.bvid,
    required this.cid,
    this.epId,
    required this.title,
    required this.partTitle,
    required this.cover,
    required this.progressSeconds,
    required this.durationSeconds,
    required this.viewAt,
  });
}

String formatSeconds(int seconds) {
  if (seconds <= 0) return '';
  final d = Duration(seconds: seconds);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
}

/// 解析出来的可播放结果
class ResolvedPlay {
  final String cid;
  final List<DashStream> videos;
  final DashStream? audio;
  final int durationSeconds;

  const ResolvedPlay({
    required this.cid,
    required this.videos,
    required this.audio,
    required this.durationSeconds,
  });
}

/// 登录用户
class BiliUser {
  final String name;
  final String mid;
  final String avatar;

  const BiliUser({required this.name, required this.mid, required this.avatar});
}

/// UP 主空间首页信息（个人资料 + 计数）
class UpInfo {
  final int mid;
  final String name;
  final String face;
  final String sign;
  final int level;
  final String officialTitle;
  final String topPhoto;
  final int following;
  final int follower;
  final int likes;

  const UpInfo({
    required this.mid,
    required this.name,
    required this.face,
    required this.sign,
    required this.level,
    required this.officialTitle,
    required this.topPhoto,
    required this.following,
    required this.follower,
    required this.likes,
  });
}

/// UP 主动态（空间动态 tab）
class UpDynamic {
  final String id;
  final String timeText;
  final String text;
  final String cover;
  final String title;
  final String bvid;
  final String playText;
  final String durationText;

  const UpDynamic({
    required this.id,
    required this.timeText,
    required this.text,
    required this.cover,
    required this.title,
    required this.bvid,
    required this.playText,
    required this.durationText,
  });
}

/// UP 主合集/视频列表
class UpCollection {
  final String id;
  final String name;
  final String cover;
  final String description;
  final int total;
  final List<VideoItem> videos;

  const UpCollection({
    required this.id,
    required this.name,
    required this.cover,
    required this.description,
    required this.total,
    required this.videos,
  });
}

/// 一条评论
class CommentItem {
  final int rpid;
  final String uname;
  final String avatar;
  final String message;
  final int ctime;
  final int like;
  final int replyCount;
  final bool liked;

  /// 评论者 mid（回复楼中楼时用 @ 提及）。
  final int mid;

  /// 是否是 UP 主自己发的评论。
  final bool isUpper;

  /// 是否是置顶评论。
  final bool isTop;

  /// 评论者等级（0~6）。
  final int level;

  /// 楼中楼预览（接口内置的前几条回复）。
  final List<CommentItem> previewReplies;

  /// 楼中楼总回复数的官方文案，如「共2314条回复」。
  final String subReplyText;

  /// 该评论被回复的父评论 rpid（楼中楼回复时非 0）。
  final int parent;

  /// 官方时间文案（B站给的「3天前发布」更贴近实际）。
  final String? officialTime;

  const CommentItem({
    required this.rpid,
    required this.uname,
    required this.avatar,
    required this.message,
    required this.ctime,
    required this.like,
    required this.replyCount,
    this.liked = false,
    this.mid = 0,
    this.isUpper = false,
    this.isTop = false,
    this.level = 0,
    this.previewReplies = const [],
    this.subReplyText = '',
    this.parent = 0,
    this.officialTime,
  });

  String get timeText {
    if (officialTime != null && officialTime!.isNotEmpty) {
      return officialTime!.replaceAll('发布', '');
    }
    final d = DateTime.fromMillisecondsSinceEpoch(ctime * 1000);
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// 楼中楼回复数文案。
  String get replyText {
    if (replyCount <= 0) return '';
    if (subReplyText.isNotEmpty) return subReplyText;
    return '共 $replyCount 条回复';
  }
}

/// 一页评论结果
class CommentPage {
  final List<CommentItem> items;
  final int next;
  final bool isEnd;
  final int total;

  const CommentPage({
    required this.items,
    required this.next,
    required this.isEnd,
    required this.total,
  });
}
