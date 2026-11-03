import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config.dart';
import 'download_service.dart';

/// Checks the CDN media manifest for changed/new/removed content.
///
/// Knowledge is automatic (startup), changes are applied explicitly: nothing
/// is ever downloaded, replaced or deleted without a user action. Detection
/// compares manifest sizes against the local sidecar basics — cheap; sha256
/// is reserved for verifying fresh downloads (see DownloadService).
class UpdateService extends ChangeNotifier {
  Manifest? _remote;
  String? lastError;
  bool checking = false;
  bool dismissedThisSession = false;
  Future<bool>? _inFlight;

  Manifest? get remote => _remote;

  /// Fetches the CDN manifest. Returns true if the manifest content changed
  /// relative to the last successful check. Silent failure (offline etc.):
  /// check `lastError`.
  ///
  /// Concurrent callers share one request instead of silently getting false.
  Future<bool> check() {
    if (!CdnConfig.useCdn) return Future.value(false);
    return _inFlight ??=
        _runCheck().whenComplete(() => _inFlight = null);
  }

  Future<bool> _runCheck() async {
    checking = true;
    lastError = null;
    notifyListeners();
    try {
      final body = await _fetchManifest();
      final manifest = Manifest.fromJson(jsonDecode(body) as Map<String, dynamic>);
      final changed = _remote == null || _remote!.version != manifest.version;
      _remote = manifest;
      return changed;
    } catch (e) {
      lastError = e.toString();
      return false;
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  Future<String> _fetchManifest() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client
          .getUrl(Uri.parse('${CdnConfig.baseUrl}/json/videos.json'))
          .timeout(const Duration(seconds: 30));
      final res = await req.close().timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) {
        throw HttpException('manifest HTTP ${res.statusCode}');
      }
      var body = await utf8.decoder.bind(res).join();
      if (body.startsWith('\ufeff')) body = body.substring(1); // PS5 BOM guard
      return body;
    } finally {
      client.close();
    }
  }

  /// Diffs the latest manifest against the local downloads.
  ///
  /// Only lessons that hold downloaded files can produce differences here —
  /// untouched content cannot become stale.
  ///
  /// Callers re-run this on every download notification (including progress
  /// ticks); the result only changes when the manifest version or the set of
  /// downloaded files changes, so it is cached on those two.
  List<LessonDiff>? _diffCache;
  String? _diffVersion;
  int _diffCount = -1;

  List<LessonDiff> diffsFor(DownloadService dl) {
    final remote = _remote;
    if (remote == null) return const [];
    final count = dl.downloadedCount;
    final cached = _diffCache;
    if (cached != null && _diffVersion == remote.version && _diffCount == count) {
      return cached;
    }
    final byLesson = <String, LessonDiff>{};
    LessonDiff groupFor(String lesson) =>
        byLesson.putIfAbsent(lesson, () => LessonDiff(lesson));
    for (final name in dl.downloadedNames) {
      final entry = remote.byName[name];
      final meta = dl.downloadedEntry(name);
      final lesson = lessonIdOf(name) ?? 'Khác';
      if (entry == null) {
        groupFor(lesson).removed.add(name); // cleanup candidate
      } else if (meta != null && entry.size != meta.size) {
        groupFor(lesson).changed.add(entry);
      }
    }
    final result = [
      for (final d in byLesson.values)
        if (!d.isEmpty) d,
    ];
    _diffCache = result;
    _diffVersion = remote.version;
    _diffCount = count;
    return result;
  }
}
