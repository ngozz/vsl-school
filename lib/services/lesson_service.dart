import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/lesson.dart';

/// Loads the bundled lesson catalogue and per-lesson outlines.
class LessonService {
  List<Lesson> _lessons = const [];
  bool _loaded = false;
  Map<String, List<String>>? _outlinesEn;

  int get count => _lessons.length;

  /// Parses `{_id,title}` entries from the bundled title.json, then overlays
  /// English titles when `data/i18n/en/titles.json` is bundled.
  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('data/json/title.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final list = data['datas'] as List<dynamic>;
    final lessons = list
        .whereType<Map<String, dynamic>>()
        .map(Lesson.fromMap)
        .where((l) => _validId(l.id))
        .toList()
      ..sort(_compare);
    final english = await _loadEnglishTitles();
    _lessons = [
      for (final lesson in lessons)
        lesson.withEnglish(english[lesson.id] ?? ''),
    ];
    _loaded = true;
  }

  Future<Map<String, String>> _loadEnglishTitles() async {
    try {
      final raw = await rootBundle.loadString('data/i18n/en/titles.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in decoded.entries)
          if (entry.value is String) entry.key: (entry.value as String).trim(),
      };
    } catch (_) {
      return const {};
    }
  }

  Future<Map<String, List<String>>> _loadEnglishOutlines() async {
    final cached = _outlinesEn;
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString('data/i18n/en/outlines.json');
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final result = <String, List<String>>{};
      for (final entry in decoded.entries) {
        if (entry.value is List) {
          result[entry.key] = [
            for (final value in entry.value as List) '$value'.trim(),
          ];
        }
      }
      return _outlinesEn = result;
    } catch (_) {
      return _outlinesEn = const {};
    }
  }

  static final RegExp _idRegex = RegExp(r'^(TOAN|TV)L([1-5])KB(\d+)$');

  static bool _validId(String id) => _idRegex.hasMatch(id);

  static int _compare(Lesson a, Lesson b) {
    final ra = _breakdown(a.id), rb = _breakdown(b.id);
    if (ra[0] != rb[0]) return ra[0].compareTo(rb[0]);
    if (ra[1] != rb[1]) return ra[1].compareTo(rb[1]);
    return ra[2].compareTo(rb[2]);
  }

  /// [subjectRank (0=TOAN,1=TV), grade, bai] — for sorting / filtering.
  static List<int> _breakdown(String id) {
    final m = _idRegex.firstMatch(id)!;
    return [
      m.group(1) == 'TOAN' ? 0 : 1,
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    ];
  }

  List<Lesson> byFilter(Subject subject, int grade) => _lessons
      .where((l) {
        final b = _breakdown(l.id);
        return b[0] == (subject == Subject.math ? 0 : 1) && b[1] == grade;
      })
      .toList();

  /// Ordered outline for one lesson. Lazily reads tablecontent, then overlays
  /// the English headings (matched by index; every source row has a video).
  Future<List<LessonSegment>> segments(String lessonId) async {
    try {
      final raw =
          await rootBundle.loadString('data/json/tablecontent/$lessonId.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = data['datas'] as List<dynamic>? ?? const [];
      final segments = list
          .whereType<Map<String, dynamic>>()
          .map(LessonSegment.fromJson)
          .whereType<LessonSegment>()
          .toList();
      final english = (await _loadEnglishOutlines())[lessonId];
      if (english == null || english.length != segments.length) {
        return segments;
      }
      return [
        for (var i = 0; i < segments.length; i++)
          segments[i].withEnglish(english[i]),
      ];
    } catch (_) {
      return const [];
    }
  }
}
