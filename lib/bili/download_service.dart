import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'client.dart';
import 'download_store.dart';
import 'models.dart';

/// 视频下载服务：DASH 视频流 + 音频流下载，ffmpeg 合并为 mp4。
///
/// 作为全局后台管理器：新任务入队后立即串行下载，进度写入 [DownloadStore]。
/// 下载目录：软件 exe 同级的 downloads 文件夹。
/// ffmpeg：软件 exe 同级的 ffmpeg.exe。
class DownloadService {
  DownloadService({required this.client, required this.store});

  final BiliClient client;
  final DownloadStore store;

  /// 每个流的下载线程数（1~16），由 UI 设置。
  int threads = 4;
  /// 总限速（字节/秒），0 表示不限速；由 UI 设置。
  int speedLimit = 0;

  /// 全局限速器（令牌桶简单实现）。
  _RateLimiter? _limiter;

  static DownloadService? _instance;
  static DownloadService get instance {
    final inst = _instance;
    if (inst == null) throw StateError('DownloadService 未初始化');
    return inst;
  }

  static void initialize({
    required BiliClient client,
    required DownloadStore store,
  }) {
    _instance ??= DownloadService(client: client, store: store);
  }

  /// 软件所在目录（exe 同级）。开发调试时回退到当前工作目录。
  Directory get appDir {
    final exe = File(Platform.resolvedExecutable);
    final parent = exe.parent;
    if (File('${parent.path}${Platform.pathSeparator}flutter_windows.dll')
        .existsSync()) {
      return parent;
    }
    return Directory.current;
  }

  Directory get downloadDir => Directory(
        '${appDir.path}${Platform.pathSeparator}downloads',
      );

/// 已解析到的 ffmpeg，缓存下来避免每次下载都去扫 PATH。
  File? _ffmpegResolved;

  /// ffmpeg 查找顺序：exe 同级 → tools/ → bin/ → %LOCALAPPDATA%\VideoHub → PATH。
  /// 发布包把 ffmpeg.exe 放在 exe 同级；开发机也可以只把它装进 PATH。
  Iterable<File> _ffmpegCandidates() sync* {
    final sep = Platform.pathSeparator;
    yield File('${appDir.path}${sep}ffmpeg.exe');
    yield File('${appDir.path}${sep}tools${sep}ffmpeg.exe');
    yield File('${appDir.path}${sep}bin${sep}ffmpeg.exe');
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData != null && localAppData.isNotEmpty) {
      yield File('$localAppData${sep}VideoHub${sep}ffmpeg.exe');
    }
    for (final entry in (Platform.environment['PATH'] ?? '').split(';')) {
      final dir = entry.trim();
      if (dir.isEmpty) continue;
      yield File('$dir${sep}ffmpeg.exe');
    }
  }

  File get ffmpegExe {
    final cached = _ffmpegResolved;
    if (cached != null && cached.existsSync()) return cached;
    for (final candidate in _ffmpegCandidates()) {
      if (candidate.existsSync()) {
        _ffmpegResolved = candidate;
        return candidate;
      }
    }
    return File('${appDir.path}${Platform.pathSeparator}ffmpeg.exe');
  }

  /// 等待队列（key 列表，避免重复入队）。
  final List<String> _queue = [];
  /// 正在下载的记录 key。
  String? _runningKey;
  bool get isRunning => _runningKey != null;

  final Map<String, CancelToken> _cancelTokens = {};

  /// 暂停令牌：与取消分开。暂停时用它中断当前请求，
  /// 但保留 .part 分段文件，继续时按 Range 从断点续传。
  final Map<String, CancelToken> _pauseTokens = {};
  /// 被用户暂停的任务 key。
  final Set<String> _pausedKeys = {};
  /// 已请求恢复、但上一次运行尚未退出的任务 key。
  final Set<String> _pendingResume = {};

  String safeFileName(String name, {int maxLen = 80}) {
    var s = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.length > maxLen) s = s.substring(0, maxLen);
    return s.isEmpty ? 'video' : s;
  }

  /// 入队下载：记录写入 store 并立即在后台开始（不弹窗）。
  /// 已完成则跳过；已在队列/运行中也跳过。
  bool enqueue(DownloadRecord record) {
    final existing = store.find(record.key);
    if (existing != null && existing.isDone && existing.outputPath.isNotEmpty) {
      if (File(existing.outputPath).existsSync()) return false;
    }
    if (_queue.contains(record.key) || _runningKey == record.key) return false;
    store.upsert(record);
    _queue.add(record.key);
    _pump();
    return true;
  }

  /// 重试失败任务。
  bool retry(String key) {
    final r = store.find(key);
    if (r == null || r.isActive || _queue.contains(key)) return false;
    r.status = DlStatus.pending;
    r.progress = 0;
    r.message = '等待下载…';
    store.update(r);
    _queue.add(key);
    _pump();
    return true;
  }

  void cancel(String key) {
    _cancelTokens[key]?.cancel();
    _pauseTokens[key]?.cancel();
    _queue.remove(key);
    _pausedKeys.remove(key);
    final r = store.find(key);
    if (r != null && (r.isActive || r.isPaused)) {
      r.status = DlStatus.canceled;
      r.message = '已取消';
      store.update(r);
    }
  }

  /// 暂停下载：中断当前请求但保留已下载的分段文件，可继续。
  void pause(String key) {
    if (!_queue.contains(key) && _runningKey != key) return;
    _pausedKeys.add(key);
    _pauseTokens[key]?.cancel();
    final r = store.find(key);
    if (r != null) {
      r.status = DlStatus.paused;
      r.message = '已暂停';
      r.speed = 0;
      r.etaSeconds = -1;
      store.update(r);
    }
  }

  /// 继续被暂停的下载（从断点续传）。
  bool resume(String key) {
    final r = store.find(key);
    if (r == null || !r.isPaused) return false;
    if (_queue.contains(key)) return false;
    _pausedKeys.remove(key);
    r.status = DlStatus.pending;
    r.message = '等待继续下载…';
    r.speed = 0;
    store.update(r);
    // 若上一次运行还没彻底退出（并行流正在收尾），
    // 先记到待恢复队列，等运行结束再重新入队。
    if (_runningKey == key) {
      _pendingResume.add(key);
      return true;
    }
    _queue.add(key);
    _pump();
    return true;
  }

  Future<void> remove(String key) async {
    cancel(key);
    final r = store.find(key);
    if (r != null && r.outputPath.isNotEmpty) {
      try {
        final f = File(r.outputPath);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }
    await store.remove(key);
  }

  /// 驱动队列：一次只跑一个任务。
  void _pump() {
    if (_runningKey != null || _queue.isEmpty) return;
    final key = _queue.removeAt(0);
    final record = store.find(key);
    if (record == null || record.isDone) {
      _pump();
      return;
    }
    _runningKey = key;
    unawaited(_run(record).whenComplete(() {
      _runningKey = null;
      _cancelTokens.remove(key);
      _pauseTokens.remove(key);
      // 暂停后用户已点「继续」→ 重新入队续传。
      if (_pendingResume.remove(key)) {
        final r = store.find(key);
        if (r != null && !r.isDone && !r.isFailed) {
          _queue.add(key);
        }
      }
      _pump();
    }));
  }

  Future<void> _run(DownloadRecord task) async {
    final cancelToken = CancelToken();
    final pauseToken = CancelToken();
    _cancelTokens[task.key] = cancelToken;
    _pauseTokens[task.key] = pauseToken;
    // 限制器按本次任务的设置创建（所有线程共享同一个限速器）。
    _limiter = speedLimit > 0 ? _RateLimiter(speedLimit) : null;
    try {
      if (!ffmpegExe.existsSync()) {
        throw Exception(
          '未找到 ffmpeg.exe：请把它放到软件目录（与 video_hub_flutter.exe 同级）或加入系统 PATH',
        );
      }
      final outDir = downloadDir;
      if (!outDir.existsSync()) await outDir.create(recursive: true);

      _touch(task, DlStatus.downloading, 0.0, '获取播放地址…');

      final play = task.epId != null
          ? await client.resolvePgc(task.epId!)
          : await client.resolve(task.bvid, cid: task.cid);

      DashStream? videoStream;
      for (final v in play.videos) {
        if (v.id == task.qualityId) {
          videoStream = v;
          break;
        }
      }
      videoStream ??= play.videos.isNotEmpty ? play.videos.first : null;
      if (videoStream == null) throw Exception('没有可用的视频流');
      final audioStream = play.audio;
      if (audioStream == null) throw Exception('没有可用的音频流（该视频可能无声音）');

      _touch(task, DlStatus.downloading, 0.0, '获取流信息…');
      final headers = client.streamHeaders;
      final videoSize = await _contentLength(videoStream.baseUrl, headers);
      final audioSize = await _contentLength(audioStream.baseUrl, headers);
      final total = videoSize + audioSize;
      task.totalBytes = total;
      // 不清零 downloadedBytes：续传时进度应从断点处接上，
      // 各分段的 onProgress 会立即上报已有字节数覆盖它。

      final base = safeFileName('${task.title} [${task.bvid}] ${videoStream.label}');
      final videoFile = File('${outDir.path}${Platform.pathSeparator}${base}.video.tmp');
      final audioFile = File('${outDir.path}${Platform.pathSeparator}${base}.audio.tmp');
      final outputFile = File('${outDir.path}${Platform.pathSeparator}${base}.mp4');

      var videoDone = 0;
      var audioDone = 0;
      var sampleBytes = 0;
      var sampleAt = DateTime.now();
      var smoothSpeed = 0.0;

      void report() {
        final now = DateTime.now();
        final done = videoDone + audioDone;
        task.downloadedBytes = done;
        // 速率必须用「本窗口增量」而不是累计下载量：
        // 用累计值算出来的是 平均速度 的累加，会一直变大。
        final elapsed = now.difference(sampleAt).inMilliseconds;
        final delta = done - sampleBytes;
        if (elapsed >= 500) {
          if (delta > 0) {
            final instant = delta * 1000.0 / elapsed;
            smoothSpeed = smoothSpeed <= 0
                ? instant
                : smoothSpeed * 0.6 + instant * 0.4;
          } else {
            // 本窗口没有新增数据（可能暂停/网络停滞）→ 速度归零。
            smoothSpeed = 0;
          }
          sampleBytes = done;
          sampleAt = now;
          task.speed = smoothSpeed;
          if (total > 0 && smoothSpeed > 0) {
            task.etaSeconds = ((total - done) / smoothSpeed).round();
          } else if (total > 0) {
            task.etaSeconds = -1;
          }
        }
        if (total > 0) {
          final p = (done / total).clamp(0.0, 0.9);
          final parts = <String>[
            '下载中 ${(p / 0.9 * 100).round()}%',
            task.sizeText,
          ];
          if (task.speedText.isNotEmpty) parts.add(task.speedText);
          if (task.etaText.isNotEmpty) parts.add(task.etaText);
          _touch(task, DlStatus.downloading, p, parts.join(' · '));
        } else {
          // 拿不到总大小时至少显示已下载量与速率。
          final parts = <String>['下载中'];
          parts.add(DownloadRecord.formatBytes(done));
          if (task.speedText.isNotEmpty) parts.add(task.speedText);
          _touch(task, DlStatus.downloading, 0.0, parts.join(' · '));
        }
      }

      final nThreads = threads.clamp(1, 16);
      await Future.wait([
        _downloadMulti(
          videoStream.baseUrl,
          videoFile,
          videoSize,
          headers,
          cancelToken,
          pauseToken,
          nThreads,
          (n) { videoDone = n; report(); },
        ),
        _downloadMulti(
          audioStream.baseUrl,
          audioFile,
          audioSize,
          headers,
          cancelToken,
          pauseToken,
          nThreads,
          (n) { audioDone = n; report(); },
        ),
      ]);

      if (cancelToken.isCancelled) throw const DownloadCanceled();
      if (pauseToken.isCancelled) throw const DownloadPaused();

      _touch(task, DlStatus.merging, 0.92, '合并音视频…');
      await _merge(videoFile, audioFile, outputFile, cancelToken);

      if (videoFile.existsSync()) await videoFile.delete();
      if (audioFile.existsSync()) await audioFile.delete();

      task.status = DlStatus.done;
      task.progress = 1.0;
      task.speed = 0;
      task.etaSeconds = -1;
      task.downloadedBytes = task.totalBytes;
      task.message = '已完成';
      task.outputPath = outputFile.path;
      await store.update(task);
    } on DownloadCanceled {
      task.status = DlStatus.canceled;
      task.message = '已取消';
      task.speed = 0;
      await store.update(task);
    } on DownloadPaused {
      // 暂停：保留 .part 分段文件，继续时从断点续传。
      // 若用户已点「继续」（_pendingResume 含此 key），不要覆盖成 paused。
      if (!_pendingResume.contains(task.key)) {
        task.status = DlStatus.paused;
        task.message = '已暂停（可继续下载）';
        task.speed = 0;
        task.etaSeconds = -1;
        await store.update(task);
      }
    } catch (e) {
      task.status = DlStatus.failed;
      task.message = '失败：$e';
      task.speed = 0;
      await store.update(task);
    }
  }

  /// 进度更新只广播刷新，不每次写盘（关键状态由 store.update 落盘）。
  void _touch(DownloadRecord task, DlStatus status, double progress, String msg) {
    task.status = status;
    task.progress = progress;
    task.message = msg;
    store.touch();
  }

  /// 用 Range: bytes=0-0 从 Content-Range 解析流总大小（HEAD 在 B站 CDN 返回 404）。
  Future<int> _contentLength(String url, Map<String, String> headers) async {
    try {
      final dio = Dio(BaseOptions(
        headers: {...headers, 'Range': 'bytes=0-0'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 10),
      ));
      final res = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final cr = res.headers.value('content-range');
      if (cr != null && cr.contains('/')) {
        final total = int.tryParse(cr.split('/').last.trim());
        if (total != null && total > 0) return total;
      }
      final len = res.headers.value('content-length');
      return int.tryParse(len ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 多线程分段下载：把文件切成 n 段并行下载到 .partN 临时文件，
  /// 完成后按序拼接成目标文件。若不支持 Range 或大小未知，退化为单线程整文件下载。
  ///
  /// 支持断点续传：每个 .partN 文件已存在时，从该段已下载的字节处继续
  /// （用 Range 请求 start+已有长度 ~ end）。
  Future<void> _downloadMulti(
    String url,
    File out,
    int size,
    Map<String, String> headers,
    CancelToken cancelToken,
    CancelToken pauseToken,
    int nThreads,
    void Function(int) onProgress,
  ) async {
    if (size <= 0 || nThreads <= 1) {
      // 单线程也统一用 .part0 段文件：
      // 这样暂停/续传的分段状态与多线程模式一致，
      // 不会因为中途改了线程数导致文件状态混乱。
      final partFile = File('${out.path}.part0');
      var have = 0;
      if (partFile.existsSync()) {
        try {
          have = await partFile.length();
        } catch (_) {
          have = 0;
        }
      }
      // 超过总大小说明文件异常，丢弃重来。
      if (size > 0 && have > size) {
        have = 0;
        try {
          await partFile.delete();
        } catch (_) {}
      }
      // 立即上报断点字节数，让进度条从断点处显示而不是从 0 开始。
      onProgress(have);
      if (size > 0 && have >= size) {
        // 该流已下完（暂停时另一条流先结束了）→ 不再请求，避免 Range 越界 416。
        await _concatParts(out, [partFile]);
        return;
      }
      await _downloadRange(
        url,
        partFile,
        headers,
        cancelToken,
        pauseToken,
        size > 0 ? '0-${size - 1}' : null,
        have,
        onProgress,
      );
      if (cancelToken.isCancelled) throw const DownloadCanceled();
      if (pauseToken.isCancelled) throw const DownloadPaused();
      await _concatParts(out, [partFile]);
      return;
    }
    final chunk = (size / nThreads).ceil();
    final parts = List<File>.generate(
      nThreads,
      (i) => File('${out.path}.part$i'),
    );
    final written = List<int>.filled(nThreads, 0);

    await Future.wait(List.generate(nThreads, (i) async {
      final start = i * chunk;
      final end = (start + chunk - 1).min(size - 1);
      if (start > end) return;
      // 断点续传：已有字节数（首次为 0）。
      final partFile = parts[i];
      var have = 0;
      if (partFile.existsSync()) {
        try {
          have = await partFile.length();
        } catch (_) {
          have = 0;
        }
        // 超过本段长度说明文件异常，丢弃重来。
        if (have > end - start + 1) {
          have = 0;
          try {
            await partFile.delete();
          } catch (_) {}
        }
      }
      written[i] = have;
      onProgress(written.fold<int>(0, (a, b) => a + b));
      if (have >= end - start + 1) return; // 本段已完成
      await _downloadRange(
        url,
        partFile,
        headers,
        cancelToken,
        pauseToken,
        '$start-$end',
        have,
        (n) {
          written[i] = n;
          onProgress(written.fold<int>(0, (a, b) => a + b));
        },
      );
    }));

    if (cancelToken.isCancelled) throw const DownloadCanceled();
    if (pauseToken.isCancelled) throw const DownloadPaused();
    // 按序拼接。
    await _concatParts(out, parts);
  }

  /// 把各分段文件按顺序拼接成目标文件，完成后删除分段。
  Future<void> _concatParts(File out, List<File> parts) async {
    final sink = out.openWrite();
    try {
      for (final part in parts) {
        if (!part.existsSync()) continue;
        await for (final chunkBytes in part.openRead()) {
          sink.add(chunkBytes);
        }
        await part.delete();
      }
    } finally {
      await sink.close();
    }
  }

  /// 下载单个 Range 段（range 为 null 时整文件），写入 [out]。
  ///
  /// [have] 是该段已下载的字节数（断点续传用）：
  /// - range 非空时起点累加，Range 请求 start+have ~ end
  /// - range 为空时用开放式 Range（bytes=have~），从已有字节继续
  /// 写入时以追加模式进行，不会覆盖已下载的内容。
  Future<void> _downloadRange(
    String url,
    File out,
    Map<String, String> headers,
    CancelToken cancelToken,
    CancelToken pauseToken,
    String? range,
    int have,
    void Function(int) onProgress,
  ) async {
    var written = have;
    String? actualRange = range;
    if (range != null && have > 0) {
      final parts = range.split('-');
      final start = int.parse(parts[0]);
      final end = int.parse(parts[1]);
      actualRange = '${start + have}-$end';
    } else if (range == null && have > 0) {
      // 整文件续传：开放式 Range。
      actualRange = 'bytes=$have-';
    }
    final dio = Dio(
      BaseOptions(
        headers: {
          ...headers,
          if (actualRange != null) 'Range': 'bytes=$actualRange',
        },
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    final res = await dio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(responseType: ResponseType.stream),
    );
    // 断点续传时追加写；否则新建覆盖写。
    final sink = out.openWrite(mode: have > 0 ? FileMode.append : FileMode.write);
    try {
      await for (final chunk in res.data!.stream) {
        if (cancelToken.isCancelled) throw const DownloadCanceled();
        if (pauseToken.isCancelled) throw const DownloadPaused();
        // 限速：按已下载总量节流。
        final limiter = _limiter;
        if (limiter != null) {
          await limiter.consume(chunk.length, cancelToken: cancelToken);
        }
        sink.add(chunk);
        written += chunk.length;
        onProgress(written);
      }
    } finally {
      // 先 flush 再 close，保证暂停/取消时已写入的字节真正落盘，
      // 否则续传时读到的文件长度会偏小，导致 Range 起点错位。
      try {
        await sink.flush();
      } catch (_) {}
      await sink.close();
    }
  }

  Future<void> _merge(
    File video,
    File audio,
    File output,
    CancelToken cancelToken,
  ) async {
    if (output.existsSync()) await output.delete();
    final result = await Process.run(
      ffmpegExe.path,
      [
        '-y',
        '-i', video.path,
        '-i', audio.path,
        '-map', '0:v:0',
        '-map', '1:a:0',
        '-c', 'copy',
        '-movflags', '+faststart',
        output.path,
      ],
      runInShell: false,
    );
    if (cancelToken.isCancelled) throw const DownloadCanceled();
    if (result.exitCode != 0) {
      throw Exception('合并失败：${result.stderr.toString().trim()}');
    }
  }
}

extension _MinExt on int {
  int min(int other) => this < other ? this : other;
}

/// 简单限速器：控制平均字节/秒，超出时 sleep 补齐时间。
/// 令牌桶限速器：所有线程共享，保证总速率不超过设定值。
///
/// 关键点：每次等待最多 sleep 100ms 并循环重算，
/// 不能一次睡几秒——那会让 UI 看起来像卡死，且无法及时响应取消/暂停。
class _RateLimiter {
  _RateLimiter(this.bytesPerSecond)
      : _tokens = bytesPerSecond.toDouble(),
        _last = DateTime.now();

  final int bytesPerSecond;
  /// 当前可用令牌（字节）。
  double _tokens;
  /// 上次补充令牌的时刻。
  DateTime _last;

  void _refill() {
    final now = DateTime.now();
    final elapsedMs = now.difference(_last).inMicroseconds / 1000.0;
    if (elapsedMs <= 0) return;
    _last = now;
    // 桶上限 = 1 秒额度，允许短时突发。
    _tokens = (_tokens + elapsedMs * bytesPerSecond / 1000.0)
        .clamp(0.0, bytesPerSecond.toDouble());
  }

  /// 消耗 [bytes] 的配额；不足时等待补足。
  Future<void> consume(int bytes, {CancelToken? cancelToken}) async {
    if (bytesPerSecond <= 0) return;
    // 单次放行上限 64KB，避免突发时一口气放太多导致速率曲线剧烈波动。
    var remaining = bytes;
    while (remaining > 0) {
      if (cancelToken?.isCancelled ?? false) return;
      _refill();
      final take = remaining > 65536 ? 65536 : remaining;
      if (_tokens >= take) {
        _tokens -= take;
        remaining -= take;
        continue;
      }
      final need = take - _tokens;
      final waitMs = (need * 1000 / bytesPerSecond).ceil().clamp(1, 100);
      await Future<void>.delayed(Duration(milliseconds: waitMs));
    }
  }
}

class DownloadCanceled implements Exception {
  const DownloadCanceled();
}

/// 任务被暂停：已下载的分段文件保留，继续时从断点续传。
class DownloadPaused implements Exception {
  const DownloadPaused();
}
