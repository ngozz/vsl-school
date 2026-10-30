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
  DateTime? lastCheck;
  String? lastError;
  bool checking = false;
  bool dismissedThisSession = false;

  Manifest? get remote => _remote;

  /// Fetches the CDN manifest. Returns true if the manifest content changed
  /// relative to the last successful check. Silent failure (offline etc.):
  /// check `lastError`.
  Future<bool> check() async {
    if (!CdnConfig.useCdn || CdnConfig.videosBundled) return false;
    if (checking) return false;
    checking = true;
    lastError = null;
    notifyListeners();
    try {
      final body = await _fetchManifest();
      final manifest = Manifest.fromJson(jsonDecode(body) as Map<String, dynamic>);
      final changed = _remote == null || _remote!.version != manifest.version;
      _remote = manifest;
      lastCheck = DateTime.now();
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
  List<LessonDiff> diffsFor(DownloadService dl) {
    final remote = _remote;
    if (remote == null) return const [];
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
    return [
      for (final d in byLesson.values)
        if (!d.isEmpty) d,
    ];
  }
}
