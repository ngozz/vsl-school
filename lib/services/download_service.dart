import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
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
///
/// The app itself is the download queue: at most [_maxConcurrent] tasks are
/// native (WorkManager) at a time, refilled from an app-side pending list.
/// Every native registration and every cancel schedules a notification
/// worker, so keeping the registered set small is what keeps the notification
/// (and cancels) quiet — concurrency alone is already bounded by the plugin's
/// native holding queue.
///
/// When the app is backgrounded a bounded [_flushWindow] of the pending list
/// is handed to the native queue (all of it on iOS, where the Dart isolate is
/// suspended); the native holding queue drips those at [_maxConcurrent] and
/// the Dart side keeps refilling while the process lives.
class DownloadService extends ChangeNotifier with WidgetsBindingObserver {
  static const _dirName = 'videos';
  static const _taskGroup = 'vsl_downloads';
  static const _maxConcurrent = 3;

  /// How many tasks may be registered with the native queue at once (about
  /// three times the concurrency: enough headroom to never starve, small
  /// enough that a cancel is a handful of ids).
  static const _flushWindow = 9;

  /// Visual minimum for the "Đang huỷ…" state, so a fast cancel still reads
  /// as feedback instead of a flicker.
  static const _cancelVisualMin = Duration(milliseconds: 550);

  final FileDownloader _dl = FileDownloader();

  /// taskId → expected manifest entry for tasks currently in flight.
  final Map<String, VideoEntry> _expect = {};

  /// video name → verified local entry (only validated copies live here).
  final Map<String, VideoEntry> _downloaded = {};

  final Map<String, double> _progress = {}; // name → 0..1
  final Map<String, TaskStatus> _status = {}; // name → TaskStatus
  final List<String> _failedNames = [];
  final Map<String, Completer<bool>> _waiters = {};
  final Map<String, String> _taskGroups = {}; // name → notification group
  final ListQueue<VideoEntry> _pending = ListQueue(); // app-side queue
  final Set<String> _pendingNames = <String>{};
  final Set<String> _canceled = <String>{}; // names the user just cancelled
  Future<void> _enqueueChain = Future<void>.value(); // serialises enqueues
  bool _canceling = false;
  int _batchTotal = 0; // baked total of the current batch (notification/UI)
  int _deleteDone = 0;
  int _deleteTotal = 0;

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

  /// True once the user confirmed a download on mobile data this session;
  /// the warning is skipped for the rest of the session and resets on app
  /// start (plain field).
  bool mobileDataConfirmedThisSession = false;

  bool isDownloaded(String name) => _downloaded.containsKey(name);

  bool isBusy(String name) {
    final s = _status[name];
    return s != null && _isBusy(s);
  }

  double progressOf(String name) => _progress[name] ?? 0;

  VideoEntry? entryFor(String name) => _catalogByName[name];

  List<VideoEntry>? entriesForLesson(String lessonId) => _lessonEntries[lessonId];

  VideoEntry? downloadedEntry(String name) => _downloaded[name];

  File fileFor(String name) => File('$_root/${_baseName(name)}.mp4');

  String _metaPath(String name) => '$_root/${_baseName(name)}.meta';

  /// Strips a stray '.mp4' so callers can pass either form; every internal
  /// map (sidecars, downloads, catalog) is keyed by extension-less names.
  static String _baseName(String name) {
    if (name.toLowerCase().endsWith('.mp4')) {
      return name.substring(0, name.length - 4);
    }
    return name;
  }

  /// Whether a verified, size-matching local copy exists right now.
  bool hasPlayableLocal(String name) {
    final n = _baseName(name);
    final meta = _downloaded[n];
    if (meta == null) return false;
    try {
      final f = fileFor(n);
      return f.existsSync() && f.lengthSync() == meta.size;
    } catch (_) {
      return false;
    }
  }

  /// Resolves when [name] reaches a terminal state: true = verified local
  /// copy ready to play; false = failed/canceled/verification error.
  Future<bool> waitFor(String name) {
    final n = _baseName(name);
    if (hasPlayableLocal(n)) return Future.value(true);
    final s = _status[n];
    if (s != null && isFailure(s)) return Future.value(false);
    return _waiters.putIfAbsent(n, () => Completer<bool>()).future;
  }

  void _completeWaiter(String name, bool ok) {
    _waiters.remove(name)?.complete(ok);
  }

  /// Resolves how a video filename plays ('TOANL1KB01_02.mp4').
  ///
  /// Downloaded copies are trusted only together with a matching size (the
  /// play-time validity check); broken/missing copies fall back to streaming.
  VideoSource resolve(String rawName) {
    final name = _baseName(rawName);
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
    WidgetsBinding.instance.addObserver(this);
    try {
      _active = !kIsWeb &&
          CdnConfig.useCdn &&
          (Platform.isAndroid || Platform.isIOS);
      if (!_active) {
        notifyListeners();
        return;
      }
      await _dl.start(autoCleanDatabase: true);
      _dl.updates.listen(_onUpdate, onError: (Object e) {
        debugPrint('[DOWNLOAD] update stream error: $e');
      });
      // Limit to a few concurrent downloads so Wi-Fi browsers and calls
      // keep bandwidth to themselves.
      _dl.configure(globalConfig: (Config.holdingQueue, (3, null, null)));
      // One merged notification for the whole batch, not one per file. The
      // text itself is (re)configured per batch inside enqueueAll — see the
      // baked-total note there.
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
    final name = _nameOf(update.task);
    // A cancelled task keeps emitting acks (and its notification worker keeps
    // running) for a while; none of that may move the in-app banner again.
    if (_canceled.contains(name)) return;
    if (update is TaskProgressUpdate) {
      if (_status.containsKey(name)) _progress[name] = update.progress;
    } else if (update is TaskStatusUpdate) {
      _status[name] = update.status;
      if (update.status == TaskStatus.complete) {
        unawaited(_finish(name, update.task));
      } else {
        if (!_isBusy(update.status)) _progress.remove(name);
        if (update.status == TaskStatus.canceled) {
          // Cancel is not a failure: no failed entry, no error notification.
          _completeWaiter(name, false);
          _taskGroups.remove(name);
          _settleBatch();
        } else if (isFailure(update.status)) {
          _failedNames.add(name);
          _completeWaiter(name, false);
          _taskGroups.remove(name);
          _settleBatch();
        }
      }
      // Top the native queue back up as slots free up.
      _refillBatch();
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
    var ok = true;
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
      ok = false;
      debugPrint('[DOWNLOAD] verify failed: $e');
      try {
        final f = fileFor(name);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
      _failedNames.add(name);
    }
    _completeWaiter(name, ok);
    _taskGroups.remove(name);
    _settleBatch();
    notifyListeners();
  }

  static String _nameOf(Task task) {
    var n = task.filename;
    if (n.toLowerCase().endsWith('.mp4')) n = n.substring(0, n.length - 4);
    return n;
  }

  // ── App-side queue ───────────────────────────────────────────────────────

  DownloadTask _buildTask(VideoEntry e, String group) => DownloadTask(
        taskId: '${e.name}.mp4',
        group: group,
        url: '${CdnConfig.baseUrl}/videos/${e.name}.mp4',
        filename: '${e.name}.mp4',
        baseDirectory: BaseDirectory.applicationSupport,
        directory: _dirName,
        allowPause: true, // resumes across Android's 9-min Worker cycles
        retries: 2,
      );

  /// Discards any old copy, then natively enqueues one task.
  ///
  /// Enqueues are serialised: a cancel can then wait for the chain and know
  /// every announced task is registered natively (otherwise it would race the
  /// plugin and cancel an id it does not know yet).
  void _enqueueNow(VideoEntry e, String group) {
    final file = fileFor(e.name);
    if (file.existsSync()) file.deleteSync();
    final sidecar = File(_metaPath(e.name));
    if (sidecar.existsSync()) sidecar.deleteSync();
    _downloaded.remove(e.name);
    _canceled.remove(e.name);
    _status[e.name] = TaskStatus.enqueued;
    _progress[e.name] = 0;
    final task = _buildTask(e, group);
    _expect[task.taskId] = e;
    _taskGroups[e.name] = group;
    _enqueueChain = _enqueueChain
        .then<void>((_) => _dl.enqueue(task))
        .catchError((Object err) {
      debugPrint('[DOWNLOAD] enqueue failed ($group): $err');
    });
  }

  /// Tops the native queue back up to [_maxConcurrent] from [_pending].
  void _refillBatch() {
    while (_pending.isNotEmpty && busyBatchCount < _maxConcurrent) {
      final e = _pending.removeFirst();
      // The name is now native, not queued: the banner derives "finished" from
      // (total − busy − pending), so a stale pending name would pin it at 0.
      _pendingNames.remove(e.name);
      _enqueueNow(e, _taskGroup);
    }
  }

  /// Called when the app is backgrounded: hand the pending list to the native
  /// queue so downloads continue after the Dart isolate is suspended.
  ///
  /// Android flushes at most [_flushWindow] tasks — the Dart side keeps
  /// refilling while the process lives, and a later cancel only has to touch
  /// that window. iOS flushes everything, because the isolate is suspended
  /// and nothing else can refill.
  void _flushPendingToNative() {
    if (_pending.isEmpty) return;
    final limit = Platform.isIOS ? _pending.length : _flushWindow;
    final tasks = <DownloadTask>[];
    while (_pending.isNotEmpty && tasks.length < limit) {
      final e = _pending.removeFirst();
      _pendingNames.remove(e.name);
      _canceled.remove(e.name);
      _status[e.name] = TaskStatus.enqueued;
      _taskGroups[e.name] = _taskGroup;
      tasks.add(_buildTask(e, _taskGroup));
    }
    _enqueueChain = _enqueueChain
        .then<void>((_) => _dl.enqueueAll(tasks))
        .catchError((Object err) {
      debugPrint('[DOWNLOAD] flush failed: $err');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _flushPendingToNative();
    } else if (state == AppLifecycleState.resumed) {
      // Slots freed while we were away: top the native queue back up and let
      // the banner re-settle (e.g. after a batch finished in the background).
      _refillBatch();
      _settleBatch();
      notifyListeners();
    }
  }

  // ── Enqueueing ───────────────────────────────────────────────────────────

  bool _isBusyOrDone(String name) =>
      _downloaded.containsKey(name) ||
      isBusy(name) ||
      _pendingNames.contains(name);

  /// Downloads [entries], skipping already-downloaded/busy/queued ones and
  /// discarding old copies first (so "changed content" replaces them).
  /// Returns the total number of videos in this batch. At most
  /// [_maxConcurrent] run natively; the rest wait in the app-side queue.
  int enqueueAll(List<VideoEntry> entries) {
    if (!_active || entries.isEmpty) return 0;
    if (_askNotifications) {
      _askNotifications = false;
      unawaited(_dl.permissions
          .request(PermissionType.notifications)
          .then<Object?>((_) => null));
    }
    var outstanding = 0;
    _taskGroups.forEach((n, g) {
      if (g == _taskGroup && isBusy(n)) outstanding++;
    });
    final slots = (_maxConcurrent - outstanding).clamp(0, _maxConcurrent);
    var created = 0;
    for (final e in entries) {
      if (_isBusyOrDone(e.name) || _pendingNames.contains(e.name)) continue;
      if (created < slots) {
        _enqueueNow(e, _taskGroup);
        created++;
      } else {
        _pending.add(e);
        _pendingNames.add(e.name);
        _canceled.remove(e.name);
      }
    }
    // Bake the true total into a neutral STATIC notification text: the
    // plugin's own {numTotal} trails (its registration jobs are batched by
    // WorkManager). The complete notification is posted by the final worker
    // — timely, and truthful even after cancels.
    final total = outstanding + created + _pendingNames.length;
    // The in-app banner uses (total − busy − pending). Keep the total
    // monotonic while a batch runs: a second call (e.g. opening a lesson that
    // is already in the batch) must not shrink the denominator.
    _batchTotal = total > _batchTotal ? total : _batchTotal;
    _canceling = false; // a fresh batch wins over a lingering cancel state
    if (!Platform.isIOS && total > 0) {
      var remainingBytes = 0;
      _expect.forEach((taskId, e) {
        if (_taskGroups[e.name] == _taskGroup) remainingBytes += e.size;
      });
      for (final e in _pending) {
        remainingBytes += e.size;
      }
      final mb = remainingBytes >= 1073741824
          ? '${(remainingBytes / 1073741824).toStringAsFixed(1)} GB'
          : '${(remainingBytes / 1048576).round()} MB';
      _dl.configureNotificationForGroup(
        _taskGroup,
        running: TaskNotification(
            'Đang tải trong nền', '$total video (~$mb MB)'),
        complete: const TaskNotification(
            'Hoàn tất tải', 'Đã tải xong {numFinished} video'),
        error: const TaskNotification('Lỗi tải bài học', '{numFailed} lỗi'),
        groupNotificationId: 'vsl_school_downloads',
      );
    }
    notifyListeners();
    return total;
  }

  int enqueueAllContent() => enqueueAll(remainingEntries());

  List<VideoEntry> remainingEntries() {
    if (!_active) return const [];
    final out = <VideoEntry>[
      ..._extras,
      ..._lessonEntries.values.expand((l) => l),
    ];
    return [
      for (final e in out)
        if (!_isBusyOrDone(e.name) && !_pendingNames.contains(e.name)) e,
    ];
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
      if (_removeOne(name)) removed++;
    }
    if (removed > 0) notifyListeners();
    return removed;
  }

  /// Cancels in-flight tasks for [names]; downloaded copies are kept.
  ///
  /// Pending (app-side queued) entries are dropped too, and the UI settles
  /// before any native call, so cancelling never looks like "it kept going".
  Future<void> cancelTasks(Iterable<String> names) =>
      _cancelNames(names, visual: true);

  /// Cancels the current batch: in-flight tasks are canceled, app-side
  /// pending entries are dropped; downloaded copies are kept.
  Future<void> cancelBatch() => _cancelNames(
        [
          ..._pendingNames,
          ..._taskGroups.entries
              .where((e) => e.value == _taskGroup)
              .map((e) => e.key),
        ],
        batch: true,
        visual: true,
      );

  /// One cancel path for every caller.
  ///
  /// 1. Drops matching entries from the app-side queue and marks them
  ///    cancelled synchronously, then repaints — the banner switches to
  ///    "Đang huỷ…" immediately.
  /// 2. Only then waits for the enqueue chain and asks the plugin to cancel
  ///    the native ids, with a timeout so the banner can never stick.
  Future<void> _cancelNames(
    Iterable<String> names, {
    bool batch = false,
    bool visual = true,
  }) async {
    final targets = {for (final n in names) _baseName(n)};
    if (targets.isEmpty) return;
    final started = DateTime.now();
    final ids = <String>[];
    var droppedFromBatch = 0;
    for (final n in targets) {
      final wasPending = _pendingNames.remove(n);
      if ((wasPending || _taskGroups[n] == _taskGroup)) droppedFromBatch++;
      if (!wasPending && isBusy(n)) ids.add('$n.mp4'); // before overwriting
      _canceled.add(n); // ignore the plugin's acks for this task
      _taskGroups.remove(n);
      _status[n] = TaskStatus.canceled;
      _progress.remove(n);
      _completeWaiter(n, false);
    }
    _pending.removeWhere((e) => targets.contains(e.name));
    // A partial cancel must not make the banner count cancelled items as
    // finished; a full batch cancel clears the total outright.
    if (batch) {
      _batchTotal = 0;
    } else if (droppedFromBatch > 0) {
      _batchTotal = (_batchTotal - droppedFromBatch).clamp(0, _batchTotal);
    }
    _canceling = visual;
    _refillBatch(); // a partial cancel must not stall the rest of the batch
    notifyListeners();

    try {
      await _enqueueChain; // let announced enqueues register first
      if (ids.isNotEmpty) {
        await _dl
            .cancelTasksWithIds(ids)
            .timeout(const Duration(seconds: 10), onTimeout: () => false)
            .catchError((Object err) {
          debugPrint('[DOWNLOAD] cancel failed: $err');
          return false;
        });
      }
      if (visual) {
        final elapsed = DateTime.now().difference(started);
        if (elapsed < _cancelVisualMin) {
          await Future<void>.delayed(_cancelVisualMin - elapsed);
        }
      }
    } finally {
      _canceling = false;
      _settleBatch();
      notifyListeners();
    }
  }

  /// Clears the baked batch total once nothing is running or queued.
  void _settleBatch() {
    if (busyBatchCount == 0 && pendingBatchCount == 0) _batchTotal = 0;
  }

  /// In-flight batch downloads (the notification group).
  int get busyBatchCount => _taskGroups.entries
      .where((e) => e.value == _taskGroup && isBusy(e.key))
      .length;

  /// Batch videos waiting in the app-side queue.
  int get pendingBatchCount => _pendingNames.length;

  /// The baked total of the current batch (0 when idle).
  int get batchTotal => _batchTotal;

  /// True while a cancel is being settled (banner shows an indeterminate bar).
  bool get canceling => _canceling;

  /// Deletion progress for the in-app banner (0/0 when idle).
  int get deleteDone => _deleteDone;
  int get deleteTotal => _deleteTotal;

  /// Deletes every downloaded copy, canceling in-flight tasks first.
  /// Reports progress via [deleteDone]/[deleteTotal] for the in-app banner.
  Future<int> deleteAll() async {
    _pending.clear();
    _pendingNames.clear();
    await _cancelNames(_catalogByName.keys, batch: true, visual: false);
    final names = _downloaded.keys.toList();
    if (names.isEmpty) return 0;
    _deleteTotal = names.length;
    _deleteDone = 0;
    notifyListeners();
    var removed = 0;
    for (final name in names) {
      if (_removeOne(name)) removed++;
      _deleteDone++;
      notifyListeners();
      // Yield so the banner can repaint between files.
      await Future<void>.delayed(Duration.zero);
    }
    _deleteDone = 0;
    _deleteTotal = 0;
    notifyListeners();
    return removed;
  }

  bool _removeOne(String name) {
    if (!_downloaded.containsKey(name)) return false;
    try {
      final f = fileFor(name);
      if (f.existsSync()) f.deleteSync();
      final m = File(_metaPath(name));
      if (m.existsSync()) m.deleteSync();
    } catch (e) {
      debugPrint('[DOWNLOAD] remove $name: $e');
      return false;
    }
    _downloaded.remove(name);
    return true;
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
