// Builds the shipped English sidecars for vsl-school from the translated work
// files.
//
// Run from the project root:
//   dart run tools/i18n/merge.dart
//
// Output:
//   data/i18n/en/titles.json      { lessonId: title }
//   data/i18n/en/outlines.json    { lessonId: [heading, ...] }
//   data/srt_en/<video>.srt       English cues, original indices/timings
//
// The SRT rebuild copies each source cue's index and timing untouched and
// replaces only the text. A video with no source SRT is skipped, so the app
// keeps its Vietnamese fallback (or shows no captions).

import 'dart:convert';
import 'dart:io';

void main() {
  final titleFile = File('data/json/title.json');
  if (!titleFile.existsSync()) {
    stderr.writeln('Run from the vsl-school project root.');
    exit(1);
  }

  final lessons = _lessons();
  final problems = <String>[];

  final titles = _mergeTitles(lessons, problems);
  final outlines = _mergeOutlines(lessons, problems);
  final videos = _mergeSubtitles(problems);

  if (problems.isNotEmpty) {
    for (final problem in problems.take(40)) {
      stderr.writeln(problem);
    }
    if (problems.length > 40) {
      stderr.writeln('… ${problems.length - 40} more');
    }
    stderr.writeln('merge aborted: ${problems.length} problem(s)');
    exit(1);
  }

  final dir = Directory('data/i18n/en')..createSync(recursive: true);
  _write('${dir.path}/titles.json', titles);
  _write('${dir.path}/outlines.json', outlines);

  stdout.writeln('titles EN: ${titles.length}');
  stdout.writeln('outlines EN: ${outlines.length} lessons');
  stdout.writeln('subtitles EN: ${videos.length} SRTs -> data/srt_en/');
}

class _Lesson {
  final String id;
  final String title;
  _Lesson(this.id, this.title);
}

List<_Lesson> _lessons() {
  final root = jsonDecode(File('data/json/title.json').readAsStringSync()) as Map;
  return [
    for (final row in (root['datas'] as List).cast<Map>())
      if (row['_id'] is String && (row['_id'] as String).isNotEmpty)
        _Lesson(row['_id'] as String, (row['title'] as String? ?? '').trim()),
  ];
}

Map<String, String> _mergeTitles(List<_Lesson> lessons, List<String> problems) {
  final json = _readJson(File('data/i18n/work/titles.json')) as Map;
  final actual = <String, String>{};
  for (final entry in json.entries) {
    if (entry.key.startsWith('_')) continue;
    actual[entry.key] = '${entry.value}'.trim();
  }

  final out = <String, String>{};
  for (final lesson in lessons) {
    final value = actual[lesson.id] ?? '';
    if (value.isEmpty) {
      problems.add('title ${lesson.id}: missing or empty');
      continue;
    }
    if (value != lesson.title) out[lesson.id] = value;
  }

  final extra = actual.keys.where((k) => !lessons.any((l) => l.id == k));
  for (final key in extra) {
    problems.add('title $key: unknown lesson');
  }
  return out;
}

Map<String, List<String>> _mergeOutlines(
  List<_Lesson> lessons,
  List<String> problems,
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
    final json = _readJson(file) as Map;
    for (final entry in json.entries) {
      if (entry.key.startsWith('_')) continue;
      if (entry.value is! List) {
        problems.add('outline ${entry.key}: not an array');
        continue;
      }
      actual[entry.key] = [for (final v in (entry.value as List)) '$v'.trim()];
    }
  }

  final out = <String, List<String>>{};
  for (final lesson in lessons) {
    final source = _sourceOutline(lesson.id);
    final translated = actual[lesson.id];
    if (translated == null) {
      problems.add('outline ${lesson.id}: missing');
      continue;
    }
    if (translated.length != source.length) {
      problems.add('outline ${lesson.id}: length ${translated.length}, '
          'expected ${source.length}');
      continue;
    }
    // Keep every heading, even unchanged ones (they are mostly sound lists).
    out[lesson.id] = translated;
  }
  return out;
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

List<String> _mergeSubtitles(List<String> problems) {
  final dir = Directory('data/i18n/work/subtitles');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'part-\d+\.json$').hasMatch(f.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  final actual = <String, Map<String, String>>{};
  for (final file in files) {
    final json = _readJson(file) as Map;
    for (final entry in json.entries) {
      if (entry.key.startsWith('_')) continue;
      if (entry.value is! Map) {
        problems.add('subtitles ${entry.key}: not an object');
        continue;
      }
      final cues = <String, String>{
        for (final cue in (entry.value as Map).entries)
          '${cue.key}': '${cue.value}'.trim(),
      };
      final previous = actual[entry.key];
      if (previous != null && !_sameCues(previous, cues)) {
        problems.add('subtitles ${entry.key}: conflicting duplicate definition');
        continue;
      }
      actual[entry.key] = cues;
    }
  }

  final target = Directory('data/srt_en')..createSync(recursive: true);
  for (final old in target.listSync().whereType<File>()) {
    if (old.path.endsWith('.srt')) old.deleteSync();
  }

  final written = <String>[];
  for (final video in actual.keys.toList()..sort()) {
    final sourceFile = File('data/srt/$video.srt');
    if (!sourceFile.existsSync()) {
      problems.add('subtitles $video: no source SRT');
      continue;
    }
    final raw = sourceFile.readAsStringSync();
    final newline = raw.contains('\r\n') ? '\r\n' : '\n';
    final sourceCues = _parseSrt(raw);
    final translated = actual[video]!;

    final missing = sourceCues.keys.where((k) => !translated.containsKey(k));
    final extra = translated.keys.where((k) => !sourceCues.containsKey(k));
    if (missing.isNotEmpty) {
      problems.add('subtitles $video: missing cues ${missing.take(8).join(', ')}');
      continue;
    }
    if (extra.isNotEmpty) {
      problems.add('subtitles $video: extra cues ${extra.take(8).join(', ')}');
      continue;
    }
    for (final cue in sourceCues.entries) {
      if (translated[cue.key]!.isEmpty) {
        problems.add('subtitles $video#${cue.key}: empty translation');
      }
    }

    final buffer = StringBuffer();
    for (final block in sourceCues.entries) {
      buffer
        ..write(block.key)
        ..write(newline)
        ..write(block.value.timing)
        ..write(newline)
        ..write(translated[block.key]!.replaceAll(RegExp(r'[\r\n]+'), ' '))
        ..write(newline)
        ..write(newline);
    }
    File('${target.path}/$video.srt')
        .writeAsStringSync(buffer.toString(), flush: true);
    written.add(video);
  }
  return written;
}

class _SourceCue {
  final String timing;
  _SourceCue(this.timing);
}

Map<String, _SourceCue> _parseSrt(String raw) {
  final text = raw.replaceFirst('\uFEFF', '');
  final result = <String, _SourceCue>{};
  for (final block in text.split(RegExp(r'\r?\n\r?\n+'))) {
    final lines = block.split(RegExp(r'\r?\n'));
    if (lines.length < 3) continue;
    final number = lines[0].trim();
    if (!RegExp(r'^\d+$').hasMatch(number)) continue;
    if (!lines[1].contains('-->')) continue;
    result[number] = _SourceCue(lines[1].trim());
  }
  return result;
}

bool _sameCues(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

dynamic _readJson(File file) {
  var text = file.readAsStringSync().replaceFirst('\uFEFF', '').trim();
  if (text.startsWith('```')) {
    text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\r?\n'), '');
    text = text.replaceFirst(RegExp(r'\r?\n```\s*$'), '');
  }
  return jsonDecode(text);
}

void _write(String path, Object json) {
  File(path).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
}
