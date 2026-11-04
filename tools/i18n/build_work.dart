// Generates the English translation work files for vsl-school.
//
// Run from the project root:
//   dart run tools/i18n/build_work.dart
//
// Output:
//   data/i18n/work/titles.json                    (150 lesson titles)
//   data/i18n/work/outlines/part-01.json ...      (871 section headings)
//   data/i18n/work/subtitles/part-01.json ...     (7,109 cues, grouped by video)
//
// Titles and outlines are maps pre-filled with Vietnamese. Outlines use a
// per-lesson ARRAY because 112 videos are shared by two different headings,
// so the video name is not a unique key. Subtitles are keyed by video + cue
// number; timings are intentionally not included, so they cannot be damaged.
//
// The parts are deterministic. A translator replaces only the Vietnamese
// values; tools/i18n/merge.dart rebuilds the shipped sidecars afterwards.

import 'dart:convert';
import 'dart:io';

const _outlineCharsPerPart = 11000;
const _cuesPerSubtitlePart = 175;

const _titlesNote =
    'Lesson titles. Translate each value into natural American English '
    'Title Case. Keep the ids as keys.';
const _outlinesNote =
    'Lesson outlines. Each value is an ordered array of section headings. '
    'Translate every heading; keep the array length and order, and keep the '
    'leading numbering exactly (for example "2.", "2.1.", "a.").';
const _subtitlesNote =
    'Subtitle cues. Keys are video names and cue numbers; do not translate '
    'them. Translate each Vietnamese text value into short, natural, spoken '
    'American English. Keep inline tags such as <i>, <b>, <sup> and '
    '<color=orange> in place.';

void main() {
  if (!File('data/json/title.json').existsSync()) {
    stderr.writeln('Run from the vsl-school project root.');
    exit(1);
  }

  final lessons = _readLessons();
  _buildTitles(lessons);
  final segments = _buildOutlines(lessons);
  final outlineCount = segments.length;
  final cueCount = _buildSubtitles(segments);

  stdout.writeln('titles: ${lessons.length} -> 1 file');
  stdout.writeln('outlines: $outlineCount headings -> '
      '${_countParts('data/i18n/work/outlines')} parts');
  stdout.writeln('subtitles: $cueCount cues -> '
      '${_countParts('data/i18n/work/subtitles')} parts');
}

class _Lesson {
  final String id;
  final String title;
  _Lesson(this.id, this.title);
}

class _Segment {
  final String lessonId;
  final String video;
  final String content;
  _Segment(this.lessonId, this.video, this.content);
}

List<_Lesson> _readLessons() {
  final root =
      jsonDecode(File('data/json/title.json').readAsStringSync()) as Map;
  return [
    for (final item in (root['datas'] as List).cast<Map>())
      if (item['_id'] is String && (item['_id'] as String).isNotEmpty)
        _Lesson(item['_id'] as String, (item['title'] as String? ?? '').trim()),
  ];
}

int _buildTitles(List<_Lesson> lessons) {
  final dir = Directory('data/i18n/work')..createSync(recursive: true);
  final map = <String, dynamic>{'_note': _titlesNote};
  for (final lesson in lessons) {
    map[lesson.id] = lesson.title;
  }
  File('${dir.path}/titles.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(map));
  return lessons.length;
}

List<_Segment> _buildOutlines(List<_Lesson> lessons) {
  final dir = Directory('data/i18n/work/outlines')..createSync(recursive: true);
  _cleanParts(dir);

  final segments = <_Segment>[];
  final parts = <Map<String, dynamic>>[];
  var part = <String, dynamic>{'_note': _outlinesNote};
  var charsInPart = 0;

  for (final lesson in lessons) {
    final file = File('data/json/tablecontent/${lesson.id}.json');
    if (!file.existsSync()) {
      stderr.writeln('missing outline: ${file.path}');
      continue;
    }
    final root = jsonDecode(file.readAsStringSync()) as Map;
    final rows = (root['datas'] as List).cast<Map>();
    final contents = <String>[];
    for (final row in rows) {
      final video = (row['video'] as String? ?? '').trim();
      final content = (row['content'] as String? ?? '').trim();
      contents.add(content);
      if (video.isNotEmpty) {
        segments.add(_Segment(lesson.id, video, content));
      }
    }
    final lessonChars = contents.fold<int>(0, (sum, s) => sum + s.length) + 40;
    if (charsInPart > 0 && charsInPart + lessonChars > _outlineCharsPerPart) {
      parts.add(part);
      part = <String, dynamic>{'_note': _outlinesNote};
      charsInPart = 0;
    }
    part[lesson.id] = contents;
    charsInPart += lessonChars;
  }
  if (charsInPart > 0) parts.add(part);

  for (var i = 0; i < parts.length; i++) {
    final name = 'part-${(i + 1).toString().padLeft(2, '0')}.json';
    File('${dir.path}/$name')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(parts[i]));
  }
  return segments;
}

int _buildSubtitles(List<_Segment> segments) {
  final dir = Directory('data/i18n/work/subtitles')
    ..createSync(recursive: true);
  _cleanParts(dir);

  final videos = <String>{
    for (final segment in segments) segment.video,
  }.toList()
    ..sort();

  final parts = <Map<String, dynamic>>[];
  var part = <String, dynamic>{'_note': _subtitlesNote};
  var cuesInPart = 0;
  var totalCues = 0;
  final missing = <String>[];

  for (final video in videos) {
    final file = File('data/srt/$video.srt');
    if (!file.existsSync()) {
      missing.add(video);
      continue;
    }
    final cues = _parseSrt(file.readAsStringSync());
    if (cues.isEmpty) {
      stderr.writeln('empty subtitles: ${file.path}');
      continue;
    }

    if (cuesInPart > 0 && cuesInPart + cues.length > _cuesPerSubtitlePart) {
      parts.add(part);
      part = <String, dynamic>{'_note': _subtitlesNote};
      cuesInPart = 0;
    }

    part[video] = {
      for (final cue in cues.entries) cue.key: cue.value,
    };
    cuesInPart += cues.length;
    totalCues += cues.length;
  }
  if (cuesInPart > 0) parts.add(part);

  for (var i = 0; i < parts.length; i++) {
    final name = 'part-${(i + 1).toString().padLeft(2, '0')}.json';
    File('${dir.path}/$name')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(parts[i]));
  }

  if (missing.isNotEmpty) {
    stdout.writeln('  segments without an SRT: ${missing.length} '
        '(${missing.join(', ')})');
  }
  return totalCues;
}

/// Parses one SRT into cueNumber -> single-line text.
///
/// Multi-line cues are joined with a space; HTML/formatting tags are kept.
/// Timings are discarded on purpose: the merge step copies them from the
/// original file.
Map<String, String> _parseSrt(String raw) {
  final text = raw.replaceFirst('\uFEFF', '');
  final result = <String, String>{};
  for (final block in text.split(RegExp(r'\r?\n\r?\n+'))) {
    final lines = block.split(RegExp(r'\r?\n'));
    if (lines.length < 3) continue;
    final number = lines[0].trim();
    if (!RegExp(r'^\d+$').hasMatch(number)) continue;
    if (!lines[1].contains('-->')) continue;
    final body = lines.sublist(2).join(' ').trim();
    if (body.isEmpty) continue;
    result[number] = body;
  }
  return result;
}

int _countParts(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return 0;
  return dir
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'part-\d+\.json$').hasMatch(f.path))
      .length;
}

void _cleanParts(Directory dir) {
  for (final entity in dir.listSync()) {
    if (entity is File && RegExp(r'part-\d+\.json$').hasMatch(entity.path)) {
      entity.deleteSync();
    }
  }
}
