import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../config.dart';

/// How the player plays a given video file.
enum VideoSource { asset, localFile, network }

/// One video file as described by the manifest (data/json/videos.json).
@immutable
class VideoEntry {
  final String name; // file name without extension, e.g. TOANL3KB01_02
  final int size;
  final String sha256;

  const VideoEntry({
    required this.name,
    required this.size,
    required this.sha256,
  });

  bool get sizeKnown => size > 0;

  factory VideoEntry.fromJson(Map<String, dynamic> j) => VideoEntry(
        name: j['n'] as String,
        size: (j['size'] as num).toInt(),
        sha256: (j['sha256'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {'n': name, 'size': size, 'sha256': sha256};
}

final RegExp _lessonRegex = RegExp(r'^(TOAN|TV)L[1-5]KB\d+');

/// Lesson id for a video name ('TOANL1KB01_02' → 'TOANL1KB01'), else null.
String? lessonIdOf(String name) => _lessonRegex.firstMatch(name)?.group(0);

/// Per-lesson differences between the CDN manifest and the local downloads.
@immutable
class LessonDiff {
  final String lesson;
  final List<VideoEntry> changed; // same name, different content on the CDN
  final List<String> removed; // downloaded locally but gone from the CDN

  const LessonDiff(
    this.lesson, {
    this.changed = const [],
    this.removed = const [],
  });

  int get bytes => changed.fold(0, (a, e) => a + e.size);
  bool get isEmpty => changed.isEmpty && removed.isEmpty;
}

/// Downloads lesson videos from the CDN and keeps verified local copies.
///
/// Every finished download is verified (size, then sha256 when known) before
/// a sidecar `<name>.meta` file is written; the sidecar is what makes a copy
/// "promoted". Startup sweeps remove anything that lacks a valid sidecar.
class DownloadService extends ChangeNotifier {
  static const _dirName = 'videos';

  final FileDownloader _dl = FileDownloader();

  /// taskId → expected manifest entry for tasks currently in flight.
  final Map<String, VideoEntry> _expect = {};

  /// video name → verified local entry (only validated copies live here).
  final Map<String, VideoEntry> _downloaded = {};

  final Map<String, double> _progress = {}; // name → 0..1
  final Map<String, TaskStatus> _status = {}; // name → TaskStatus
  final List<String> _failedNames = [];

  final Map<String, VideoEntry> _catalogByName = {};
  final Map<String, List<VideoEntry>> _lessonEntries = {};
  List<VideoEntry> _extras = const [];

  String _root = '';
  bool _ready = false;
  bool _active = false;
  bool _askNotifications = true;

  /// False on bundled (full) APKs, web and unsupported platforms.
  bool get active => _active;
  bool get ready => _ready;
  int get downloadedCount => _downloaded.length;
  int get downloadedBytes => _downloaded.values.fold(0, (a, e) => a + e.size);
  Set<String> get downloadedNames => _downloaded.keys.toSet();
  int get downloadedLessonCount =>
      _downloaded.keys.map(lessonIdOf).whereType<String>().toSet().length;
  int get catalogLessonCount => _lessonEntries.length;
  List<String> get failedNames => _failedNames.toList();

  bool isDownloaded(String name) => _downloaded.containsKey(name);

  bool isBusy(String name) {
    final s = _status[name];
    return s != null && _isBusy(s);
  }

  double progressOf(String name) => _progress[name] ?? 0;

  VideoEntry? entryFor(String name) => _catalogByName[name];

  List<VideoEntry>? entriesForLesson(String lessonId) => _lessonEntries[lessonId];

  VideoEntry? downloadedEntry(String name) => _downloaded[name];

  File fileFor(String name) => File('$_root/$name.mp4');

  String _metaPath(String name) => '$_root/$name.meta';

  /// Resolves how a video filename plays ('TOANL1KB01_02.mp4').
  ///
  /// Downloaded copies are trusted only together with a matching size (the
  /// play-time validity check); broken/missing copies fall back to streaming.
  VideoSource resolve(String name) {
    if (CdnConfig.videosBundled) return VideoSource.asset;
    final meta = _downloaded[name];
    if (meta != null) {
      try {
        final f = fileFor(name);
        if (f.existsSync() && f.lengthSync() == meta.size) {
          return VideoSource.localFile;
        }
      } catch (_) {}
      // Invalid copy (corrupt / missing) — falls through; the sweep
      // deletes it at next startup.
    }
    if (CdnConfig.useCdn) return VideoSource.network;
    return VideoSource.asset;
  }

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _ready = true; // guards double init
    try {
      _active = !kIsWeb &&
          !CdnConfig.videosBundled &&
          (Platform.isAndroid || Platform.isIOS);
      if (!_active) {
        notifyListeners();
        return;
      }
      await _dl.start(autoCleanDatabase: true);
      _dl.updates.listen(_onUpdate, onError: (Object e) {
        debugPrint('[DOWNLOAD] update stream error: $e');
      });
      _dl.configureNotification(
        running: const TaskNotification('Đang tải bài học', '{filename}'),
        progressBar: true,
      );
      final base = await getApplicationSupportDirectory();
      _root = '${base.path}/$_dirName';
      await Directory(_root).create(recursive: true);
      await _loadCatalog();
      await _sweepAndLoad();
    } catch (e) {
      debugPrint('[DOWNLOAD] init failed: $e');
      _active = false;
    }
    notifyListeners();
  }

  /// Loads the bundled per-lesson manifest (sizes + sha256 for verification).
  Future<void> _loadCatalog() async {
    try {
      final raw = await rootBundle.loadString('data/json/videos.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final lessons = (map['lessons'] as Map<String, dynamic>?) ?? {};
      _lessonEntries
        ..clear()
        ..addEntries(lessons.entries.map((e) => MapEntry(
              e.key,
              [
                for (final j in (e.value as List).cast<Map<String, dynamic>>())
                  VideoEntry.fromJson(j)
              ],
            )));
      _extras = [
        for (final j
            in ((map['extras'] as List?) ?? const []).cast<Map<String, dynamic>>())
          VideoEntry.fromJson(j)
      ];
      _catalogByName
        ..clear()
        ..addEntries([
          for (final list in _lessonEntries.values)
            for (final e in list) MapEntry(e.name, e),
          for (final e in _extras) MapEntry(e.name, e),
        ]);
    } catch (e) {
      debugPrint('[DOWNLOAD] manifest unavailable: $e');
    }
  }

  /// Loads sidecar-verified downloads; removes incomplete/corrupt leftovers.
  ///
  /// Order matters: exact-size catalog matches are promoted first (heals
  /// copies completed while the app was closed, before their sidecar was
  /// written), then anything still sidecar-less is cleaned up.
  Future<void> _sweepAndLoad() async {
    try {
      for (final f in Directory(_root).listSync().whereType<File>().toList()) {
        if (!f.path.toLowerCase().endsWith('.mp4')) continue;
        final n = f.path.split('/').last;
        final name = n.substring(0, n.length - 4);
        final entry = _catalogByName[name];
        if (entry == null) {
          await f.delete(); // stray/junk file
        } else if (entry.sizeKnown && f.lengthSync() == entry.size) {
          await _promote(name, entry.size, entry.sha256);
        }
      }
      // Anything still without a valid sidecar is broken: clean it up.
      for (final f in Directory(_root).listSync().whereType<File>().toList()) {
        final p = f.path.split('/').last;
        final lower = p.toLowerCase();
        if (lower.endsWith('.mp4')) {
          final name = p.substring(0, p.length - 4);
          if (_downloaded.containsKey(name)) continue;
          await f.delete();
        } else if (lower.endsWith('.meta')) {
          final name = p.substring(0, p.length - 5);
          if (_downloaded.containsKey(name)) continue;
          await f.delete(); // orphaned sidecar
        } else {
          await f.delete(); // unknown junk
        }
      }
    } catch (e) {
      debugPrint('[DOWNLOAD] sweep: $e');
    }
  }

  Future<void> _promote(String name, int size, String sha) async {
    _downloaded[name] = VideoEntry(name: name, size: size, sha256: sha);
    if (!File(_metaPath(name)).existsSync()) {
      try {
        await File(_metaPath(name)).writeAsString(jsonEncode(
            {'name': name, 'size': size, 'sha256': sha}));
      } catch (_) {}
    }
  }

  // ── Events ───────────────────────────────────────────────────────────────

  void _onUpdate(TaskUpdate update) {
    if (update is TaskProgressUpdate) {
      final name = _nameOf(update.task);
      if (_status.containsKey(name)) _progress[name] = update.progress;
    } else if (update is TaskStatusUpdate) {
      final name = _nameOf(update.task);
      _status[name] = update.status;
      if (update.status == TaskStatus.complete) {
        unawaited(_finish(name, update.task));
      } else {
        if (!_isBusy(update.status)) _progress.remove(name);
        if (isFailure(update.status)) _failedNames.add(name);
      }
    }
    notifyListeners();
  }

  static bool _isBusy(TaskStatus s) =>
      s == TaskStatus.enqueued ||
      s == TaskStatus.running ||
      s == TaskStatus.waitingToRetry ||
      s == TaskStatus.paused;

  /// `true` for statuses meaning the task will not complete unaided.
  static bool isFailure(TaskStatus s) =>
      s == TaskStatus.failed ||
      s == TaskStatus.canceled ||
      s == TaskStatus.notFound;

  Future<void> _finish(String name, Task task) async {
    try {
      final file = fileFor(name);
      if (!file.existsSync()) {
        throw FileSystemException('missing after download', file.path);
      }
      final expected = _expect.remove(task.taskId);
      final actual = file.lengthSync();
      if (expected != null && expected.sizeKnown && actual != expected.size) {
        throw FileSystemException(
            'size mismatch for $name ($actual != ${expected.size})', file.path);
      }
      var sha = '';
      final expectedSha = expected?.sha256 ?? '';
      if (expectedSha.isNotEmpty) {
        sha = (await crypto.sha256.bind(file.openRead()).single).toString();
        if (sha != expectedSha) {
          throw FileSystemException('sha mismatch for $name', file.path);
        }
      }
      await _promote(name, actual, sha);
      await File(_metaPath(name)).writeAsString(
          jsonEncode({'name': name, 'size': actual, 'sha256': sha}));
      _progress.remove(name);
    } catch (e) {
      debugPrint('[DOWNLOAD] verify failed: $e');
      try {
        final f = fileFor(name);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
      _failedNames.add(name);
    }
    notifyListeners();
  }

  static String _nameOf(Task task) {
    var n = task.filename;
    if (n.toLowerCase().endsWith('.mp4')) n = n.substring(0, n.length - 4);
    return n;
  }

  // ── Enqueueing ───────────────────────────────────────────────────────────

  bool _isBusyOrDone(String name) =>
      _downloaded.containsKey(name) || isBusy(name);

  /// Downloads [entries], skipping already-downloaded/busy ones and discarding
  /// old copies first (so "changed content" replaces them). Returns how many
  /// tasks were created. Downloads continue after app close (WorkManager on
  /// Android, background URLSession on iOS).
  int enqueueAll(List<VideoEntry> entries) {
    if (!_active || entries.isEmpty) return 0;
    if (_askNotifications) {
      _askNotifications = false;
      unawaited(_dl.permissions
          .request(PermissionType.notifications)
          .then<Object?>((_) => null));
    }
    var created = 0;
    final tasks = <DownloadTask>[];
    for (final e in entries) {
      if (_isBusyOrDone(e.name)) continue;
      final file = fileFor(e.name);
      if (file.existsSync()) file.deleteSync();
      final sidecar = File(_metaPath(e.name));
      if (sidecar.existsSync()) sidecar.deleteSync();
      _downloaded.remove(e.name);
      _status[e.name] = TaskStatus.enqueued;
      _progress[e.name] = 0;
      final task = DownloadTask(
        taskId: '${e.name}.mp4',
        url: '${CdnConfig.baseUrl}/videos/${e.name}.mp4',
        filename: '${e.name}.mp4',
        baseDirectory: BaseDirectory.applicationSupport,
        directory: _dirName,
        allowPause: true, // resumes across Android's 9-min Worker cycles
        retries: 2,
      );
      tasks.add(task);
      _expect[task.taskId] = e;
      created++;
    }
    unawaited(_dl.enqueueAll(tasks));
    notifyListeners();
    return created;
  }

  int enqueueAllContent() => enqueueAll(remainingEntries());

  List<VideoEntry> remainingEntries() {
    if (!_active) return const [];
    final out = <VideoEntry>[
      ..._extras,
      ..._lessonEntries.values.expand((l) => l),
    ];
    return [for (final e in out) if (!_isBusyOrDone(e.name)) e];
  }

  bool allDownloaded(Iterable<String> names) =>
      names.isNotEmpty && names.every(_downloaded.containsKey);

  double lessonProgress(Iterable<String> names) {
    var sum = 0.0;
    var n = 0;
    for (final name in names) {
      if (_downloaded.containsKey(name)) {
        sum += 1.0;
      } else if (isBusy(name)) {
        sum += _progress[name] ?? 0;
      }
      n++;
    }
    return n == 0 ? 1.0 : sum / n;
  }

  /// Removes local copies explicitly (user-requested cleanup).
  int removeLocal(List<String> names) {
    var removed = 0;
    for (final name in names) {
      if (!_downloaded.containsKey(name)) continue;
      try {
        final f = fileFor(name);
        if (f.existsSync()) f.deleteSync();
        final m = File(_metaPath(name));
        if (m.existsSync()) m.deleteSync();
      } catch (e) {
        debugPrint('[DOWNLOAD] remove $name: $e');
        continue;
      }
      _downloaded.remove(name);
      removed++;
    }
    if (removed > 0) notifyListeners();
    return removed;
  }

  // ── Network detection (Wi-Fi / mobile-data UX) ──────────────────────────

  Future<bool> onWifi() async {
    final r = await Connectivity().checkConnectivity();
    return r.contains(ConnectivityResult.wifi) ||
        r.contains(ConnectivityResult.ethernet);
  }
}

/// Parses the whole CDN manifest (same layout as the bundled
/// data/json/videos.json) for update checks.
class Manifest {
  final String version;
  final Map<String, List<VideoEntry>> lessons;
  final List<VideoEntry> extras;
  final Map<String, VideoEntry> byName;

  const Manifest(this.version, this.lessons, this.extras, this.byName);

  static Manifest fromJson(Map<String, dynamic> j) {
    final lessons = <String, List<VideoEntry>>{};
    final byName = <String, VideoEntry>{};
    final jm = (j['lessons'] as Map<String, dynamic>?) ?? {};
    jm.forEach((k, v) {
      final list = [
        for (final e in (v as List).cast<Map<String, dynamic>>())
          VideoEntry.fromJson(e)
      ];
      lessons[k] = list;
      for (final e in list) {
        byName[e.name] = e;
      }
    });
    final extras = [
      for (final e
          in ((j['extras'] as List?) ?? const []).cast<Map<String, dynamic>>())
        VideoEntry.fromJson(e)
    ];
    for (final e in extras) {
      byName[e.name] = e;
    }
    return Manifest((j['version'] as String?) ?? '', lessons, extras, byName);
  }
}
