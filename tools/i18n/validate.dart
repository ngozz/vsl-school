// Validates the English school work files before merging.
//
// Run from the project root:
//   dart run tools/i18n/validate.dart
//
// ERRORS block the merge (missing keys, changed array lengths, changed cue
// lists, empty text). FLAGS are review signals (leftover Vietnamese,
// unchanged lines, tag/number drift, overlong subtitles).

import 'dart:convert';
import 'dart:io';

final _vi = RegExp(
  r'[àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ]',
  caseSensitive: false,
);
const _names = [
  'Hồ Chí Minh',
  'Việt Nam',
  'Hà Nội',
  'Đà Nẵng',
  'Sài Gòn',
  'Huế',
  'Cần Thơ',
  'Hải Phòng',
  'Nha Trang',
  'Vũng Tàu',
  'Hạ Long',
  'Điện Biên',
  'Trường Sa',
  'Hoàng Sa',
  'Khiem Thinh',
];
final _prefix = RegExp(
  r'^\s*((?:\d+(?:\.\d+)*\.?)|(?:[a-zA-Z]\.)|(?:[IVXLC]+\.))',
);

void main() {
  final lessons = _readLessons();
  final errors = <String>[];
  final flags = <String>[];
  final summary = <String, int>{};

  _titles(lessons, errors, flags, summary);
  _outlines(lessons, errors, flags, summary);
  _subtitles(lessons, errors, flags, summary);

  final out = StringBuffer()
    ..writeln('== school ==')
    ..writeln('lessons: ${lessons.length}')
    ..writeln('ERRORS: ${errors.length}')
    ..writeln('FLAGS: ${flags.length}');
  for (final e in summary.entries) {
    if (e.value > 0) out.writeln('  ${e.key}: ${e.value}');
  }
  if (errors.isNotEmpty) {
    out.writeln('\n-- errors --');
    for (final e in errors.take(50)) {
      out.writeln('  $e');
    }
    if (errors.length > 50) out.writeln('  … ${errors.length - 50} more');
  }
  if (flags.isNotEmpty) {
    out.writeln('\n-- flags --');
    for (final f in flags.take(50)) {
      out.writeln('  $f');
    }
    if (flags.length > 50) out.writeln('  … ${flags.length - 50} more');
  }
  stdout.write(out);
  Directory('data/i18n').createSync(recursive: true);
  final full = StringBuffer()
    ..writeln('== school ==')
    ..writeln('lessons: ${lessons.length}')
    ..writeln('ERRORS: ${errors.length}')
    ..writeln('FLAGS: ${flags.length}');
  for (final e in errors) {
    full.writeln('E $e');
  }
  for (final f in flags) {
    full.writeln('F $f');
  }
  File('data/i18n/validation-school.txt').writeAsStringSync(full.toString());

  exitCode = errors.isEmpty ? 0 : 1;
}

class _Lesson {
  final String id;
  final String title;
  _Lesson(this.id, this.title);
}

List<_Lesson> _readLessons() {
  final root =
      jsonDecode(File('data/json/title.json').readAsStringSync()) as Map;
  return [
    for (final row in (root['datas'] as List).cast<Map>())
      _Lesson(row['_id'] as String, (row['title'] as String? ?? '').trim()),
  ];
}

void _titles(
  List<_Lesson> lessons,
  List<String> errors,
  List<String> flags,
  Map<String, int> summary,
) {
  final json = _readJson(File('data/i18n/work/titles.json'));
  if (json is! Map) {
    errors.add('titles.json: not a JSON object');
    return;
  }
  final actual = <String, String>{};
  for (final e in json.entries) {
    if (e.key.startsWith('_')) continue;
    if (e.value is! String) {
      errors.add('titles.json: ${e.key} is not a string');
      continue;
    }
    actual[e.key] = e.value as String;
  }
  for (final l in lessons) {
    final out = actual[l.id]?.trim();
    if (out == null || out.isEmpty) {
      errors.add('title ${l.id}: missing or empty');
      continue;
    }
    if (_viLeft(out)) {
      _bump(summary, 'title Vietnamese');
      flags.add('title ${l.id}: Vietnamese left: $out');
    }
    if (out.toLowerCase() == l.title.toLowerCase()) {
      _bump(summary, 'title unchanged');
      flags.add('title ${l.id}: unchanged');
    }
    if (out.endsWith('.')) {
      _bump(summary, 'title trailing period');
      flags.add('title ${l.id}: trailing period');
    }
    if (RegExp(r'\bMaths\b').hasMatch(out)) {
      _bump(summary, 'title Maths');
      flags.add('title ${l.id}: "Maths"');
    }
  }
  final extra = actual.keys.where((k) => !lessons.any((l) => l.id == k)).toList();
  if (extra.isNotEmpty) errors.add('titles.json: extra keys ${extra.take(8).join(', ')}');
}

void _outlines(
  List<_Lesson> lessons,
  List<String> errors,
  List<String> flags,
  Map<String, int> summary,
) {
  final dir = Directory('data/i18n/work/outlines');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'part-\d+\.json$').hasMatch(f.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final actual = <String, List<String>>{};
  for (final file in files) {
    final name = _base(file.path);
    final json = _readJson(file);
    if (json is! Map) {
      errors.add('$name: not a JSON object');
      continue;
    }
    for (final e in json.entries) {
      if (e.key.startsWith('_')) continue;
      if (e.value is! List) {
        errors.add('$name: ${e.key} is not an array');
        continue;
      }
      actual[e.key] = [for (final v in e.value as List) '$v'];
    }
  }

  var headings = 0;
  for (final lesson in lessons) {
    final src = _sourceOutline(lesson.id);
    final out = actual[lesson.id];
    if (out == null) {
      errors.add('outline ${lesson.id}: missing');
      continue;
    }
    if (out.length != src.length) {
      errors.add('outline ${lesson.id}: length ${out.length}, expected ${src.length}');
      continue;
    }
    for (var i = 0; i < src.length; i++) {
      headings++;
      final s = src[i].trim();
      final o = out[i].trim();
      final label = '${lesson.id}[$i]';
      if (o.isEmpty && s.isNotEmpty) {
        errors.add('$label: empty');
        continue;
      }
      if (_viLeft(o)) {
        _bump(summary, 'outline Vietnamese');
        flags.add('$label: Vietnamese left');
      }
      if (o.toLowerCase() == s.toLowerCase() && _hasLetters(s) && s.length > 3) {
        _bump(summary, 'outline unchanged');
        flags.add('$label: unchanged');
      }
      final ps = _prefix.firstMatch(s)?.group(1)?.toLowerCase();
      final po = _prefix.firstMatch(o)?.group(1)?.toLowerCase();
      if (ps != null && ps != po) {
        _bump(summary, 'outline numbering');
        flags.add('$label: numbering "$ps" -> "$po"');
      }
      if (!_sameNumbers(s, o)) {
        _bump(summary, 'outline numbers');
        flags.add('$label: numbers changed');
      }
    }
  }
  final extra = actual.keys.where((k) => !lessons.any((l) => l.id == k)).toList();
  if (extra.isNotEmpty) errors.add('outlines: extra lessons ${extra.take(8).join(', ')}');
  _bump(summary, 'outline headings', headings);
}

List<String> _sourceOutline(String lessonId) {
  final file = File('data/json/tablecontent/$lessonId.json');
  if (!file.existsSync()) return const [];
  final root = jsonDecode(file.readAsStringSync()) as Map;
  return [
    for (final row in (root['datas'] as List).cast<Map>())
      (row['content'] as String? ?? '').trim(),
  ];
}

void _subtitles(
  List<_Lesson> lessons,
  List<String> errors,
  List<String> flags,
  Map<String, int> summary,
) {
  final dir = Directory('data/i18n/work/subtitles');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'part-\d+\.json$').hasMatch(f.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final actual = <String, Map<String, String>>{};
  for (final file in files) {
    final name = _base(file.path);
    final json = _readJson(file);
    if (json is! Map) {
      errors.add('$name: not a JSON object');
      continue;
    }
    for (final e in json.entries) {
      if (e.key.startsWith('_')) continue;
      if (e.value is! Map) {
        errors.add('$name: ${e.key} is not an object');
        continue;
      }
      final cues = <String, String>{};
      for (final cue in (e.value as Map).entries) {
        cues['${cue.key}'] = '${cue.value}';
      }
      actual[e.key] = cues;
    }
  }

  // Only videos that have a source SRT and are referenced by an outline.
  final referenced = <String>{};
  for (final lesson in lessons) {
    final file = File('data/json/tablecontent/${lesson.id}.json');
    if (!file.existsSync()) continue;
    final root = jsonDecode(file.readAsStringSync()) as Map;
    for (final row in (root['datas'] as List).cast<Map>()) {
      final video = (row['video'] as String? ?? '').trim();
      if (video.isNotEmpty && File('data/srt/$video.srt').existsSync()) {
        referenced.add(video);
      }
    }
  }

  var cues = 0;
  for (final video in referenced) {
    final src = _parseSrt(File('data/srt/$video.srt').readAsStringSync());
    final out = actual[video];
    if (out == null) {
      errors.add('subtitles $video: missing');
      continue;
    }
    final missing = src.keys.where((k) => !out.containsKey(k)).toList();
    final extra = out.keys.where((k) => !src.containsKey(k)).toList();
    if (missing.isNotEmpty) {
      errors.add('subtitles $video: missing cues ${missing.take(8).join(', ')}');
      continue;
    }
    if (extra.isNotEmpty) {
      errors.add('subtitles $video: extra cues ${extra.take(8).join(', ')}');
      continue;
    }
    for (final cue in src.entries) {
      cues++;
      final s = cue.value.trim();
      final o = out[cue.key]!.trim();
      final label = '$video#${cue.key}';
      if (o.isEmpty && s.isNotEmpty) {
        errors.add('$label: empty');
        continue;
      }
      if (o.contains('\n') || o.contains('\r')) {
        _bump(summary, 'subtitle newline');
        flags.add('$label: contains a newline');
      }
      if (_viLeft(o)) {
        _bump(summary, 'subtitle Vietnamese');
        flags.add('$label: Vietnamese left: ${_cut(o)}');
      }
      if (o.toLowerCase() == s.toLowerCase() && _hasLetters(s) && s.length > 3) {
        _bump(summary, 'subtitle unchanged');
        flags.add('$label: unchanged: ${_cut(o)}');
      }
      if (!_sameTags(s, o)) {
        _bump(summary, 'subtitle tags');
        flags.add('$label: tags changed');
      }
      if (!_sameNumbers(s, o)) {
        _bump(summary, 'subtitle numbers');
        flags.add('$label: numbers changed: ${_cut(s)} -> ${_cut(o)}');
      }
      final limit = (s.length * 2.5 + 20).clamp(120, 260).toDouble();
      if (o.length > limit) {
        _bump(summary, 'subtitle overlong');
        flags.add('$label: ${o.length} chars (source ${s.length})');
      }
      if (RegExp(r'\bMaths\b').hasMatch(o)) {
        _bump(summary, 'subtitle Maths');
        flags.add('$label: "Maths"');
      }
    }
  }

  final extraVideos = actual.keys.where((v) => !referenced.contains(v)).toList();
  if (extraVideos.isNotEmpty) {
    errors.add('subtitles: unreferenced videos ${extraVideos.take(8).join(', ')}');
  }
  _bump(summary, 'subtitle cues', cues);
}

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

dynamic _readJson(File file) {
  var text = file.readAsStringSync().replaceFirst('\uFEFF', '').trim();
  if (text.startsWith('```')) {
    text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\r?\n'), '');
    text = text.replaceFirst(RegExp(r'\r?\n```\s*$'), '');
  }
  return jsonDecode(text);
}

String _base(String path) => path.split(RegExp(r'[\\/]')).last;

bool _viLeft(String text) => _vi.hasMatch(_stripNames(text));

String _stripNames(String text) {
  var out = text;
  for (final name in _names) {
    out = out.replaceAll(name, '');
  }
  return out;
}

bool _hasLetters(String s) => RegExp(r'[a-zA-ZÀ-ỹ]').hasMatch(s);

bool _sameNumbers(String a, String b) {
  final na = RegExp(r'\d+').allMatches(a).map((m) => m.group(0)!).toList()
    ..sort();
  final nb = RegExp(r'\d+').allMatches(b).map((m) => m.group(0)!).toList()
    ..sort();
  if (na.length != nb.length) return false;
  for (var i = 0; i < na.length; i++) {
    if (na[i] != nb[i]) return false;
  }
  return true;
}

bool _sameTags(String a, String b) {
  final ta = RegExp(r'<[^>]+>').allMatches(a).map((m) => m.group(0)!).toList()
    ..sort();
  final tb = RegExp(r'<[^>]+>').allMatches(b).map((m) => m.group(0)!).toList()
    ..sort();
  if (ta.length != tb.length) return false;
  for (var i = 0; i < ta.length; i++) {
    if (ta[i].toLowerCase() != tb[i].toLowerCase()) return false;
  }
  return true;
}

String _cut(String s) => s.length <= 60 ? s : '${s.substring(0, 60)}…';

void _bump(Map<String, int> map, String key, [int by = 1]) {
  map[key] = (map[key] ?? 0) + by;
}
