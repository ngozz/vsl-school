import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/lesson.dart';

/// Loads the bundled lesson catalogue and per-lesson outlines.
class LessonService {
  List<Lesson> _lessons = const [];
  bool _loaded = false;

  bool get isLoaded => _loaded;
  int get count => _lessons.length;

  /// Parses `{_id,title}` entries from the bundled title.json.
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
    _lessons = lessons;
    _loaded = true;
  }

  static bool _validId(String id) =>
      RegExp(r'^(TOAN|TV)L([1-5])KB(\d+)$').hasMatch(id);

  static int _compare(Lesson a, Lesson b) {
    final ra = _breakdown(a.id), rb = _breakdown(b.id);
    if (ra[0] != rb[0]) return ra[0].compareTo(rb[0]);
    if (ra[1] != rb[1]) return ra[1].compareTo(rb[1]);
    return ra[2].compareTo(rb[2]);
  }

  /// [subjectRank (0=TOAN,1=TV), grade, bai] — for sorting / filtering.
  static List<int> _breakdown(String id) {
    final m = RegExp(r'^(TOAN|TV)L([1-5])KB(\d+)$').firstMatch(id)!;
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

  /// Ordered outline for one lesson. Lazily reads tablecontent.
  Future<List<LessonSegment>> segments(String lessonId) async {
    try {
      final raw =
          await rootBundle.loadString('data/json/tablecontent/$lessonId.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = data['datas'] as List<dynamic>? ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(LessonSegment.fromJson)
          .whereType<LessonSegment>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
