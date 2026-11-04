// Verifies the merged English school sidecars against the Vietnamese source.
//
// Run from the project root:
//   dart run tools/i18n/verify.dart
//
// Checks:
//   * every data/srt_en/*.srt has a source SRT with identical cue indices and
//     timings, and text equal to the translated work value;
//   * no source-with-SRT video is missing an English file;
//   * titles and outlines cover every lesson with the expected array lengths.

import 'dart:convert';
import 'dart:io';

void main() {
  final problems = <String>[];
  final lessons = _lessons();
  final videos = _videos(lessons);

  _checkTitles(lessons, problems);
  _checkOutlines(lessons, problems);
  _checkSubtitles(videos, problems);

  if (problems.isEmpty) {
    stdout.writeln('OK: titles ${lessons.length}, outlines ${lessons.length}, '
        'subtitles ${videos.length}');
    return;
  }
  for (final problem in problems) {
    stderr.writeln(problem);
  }
  exit(1);
}

class _Lesson {
  final String id;
  _Lesson(this.id);
}

List<_Lesson> _lessons() {
  final root = jsonDecode(File('data/json/title.json').readAsStringSync()) as Map;
  return [
    for (final row in (root['datas'] as List).cast<Map>())
      _Lesson(row['_id'] as String),
  ];
}

Set<String> _videos(List<_Lesson> lessons) {
  final out = <String>{};
  for (final lesson in lessons) {
    final root = jsonDecode(
      File('data/json/tablecontent/${lesson.id}.json').readAsStringSync(),
    ) as Map;
    for (final row in (root['datas'] as List).cast<Map>()) {
      final video = (row['video'] as String? ?? '').trim();
      if (video.isNotEmpty && File('data/srt/$video.srt').existsSync()) {
        out.add(video);
      }
    }
  }
  return out;
}

void _checkTitles(List<_Lesson> lessons, List<String> problems) {
  final titles = jsonDecode(
    File('data/i18n/en/titles.json').readAsStringSync(),
  ) as Map;
  for (final lesson in lessons) {
    final value = titles[lesson.id];
    if (value is! String || value.trim().isEmpty) {
      problems.add('title ${lesson.id}: missing');
    }
  }
}

void _checkOutlines(List<_Lesson> lessons, List<String> problems) {
  final outlines = jsonDecode(
    File('data/i18n/en/outlines.json').readAsStringSync(),
  ) as Map;
  for (final lesson in lessons) {
    final value = outlines[lesson.id];
    if (value is! List) {
      problems.add('outline ${lesson.id}: missing');
      continue;
    }
    final source = (jsonDecode(
      File('data/json/tablecontent/${lesson.id}.json').readAsStringSync(),
    ) as Map)['datas'] as List;
    if (value.length != source.length) {
      problems.add('outline ${lesson.id}: length ${value.length}, '
          'expected ${source.length}');
    }
  }
}

void _checkSubtitles(Set<String> videos, List<String> problems) {
  final translated = _workCues();
  final files = Directory('data/srt_en')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.srt'))
      .toList();
  final seen = <String>{};

  for (final file in files) {
    final video = file.path.split(RegExp(r'[\\/]')).last.replaceAll('.srt', '');
    seen.add(video);
    final source = _parse(File('data/srt/$video.srt').readAsStringSync());
    final english = _parse(file.readAsStringSync());
    if (source.length != english.length) {
      problems.add('$video: cue count ${english.length}, '
          'expected ${source.length}');
      continue;
    }
    final cues = translated[video];
    for (final entry in source.entries) {
      final out = english[entry.key];
      if (out == null) {
        problems.add('$video#${entry.key}: missing cue');
        continue;
      }
      if (out.timing != entry.value.timing) {
        problems.add('$video#${entry.key}: timing changed');
      }
      if (cues != null && out.text != cues[entry.key]) {
        problems.add('$video#${entry.key}: text differs from work file');
      }
    }
  }

  for (final video in videos) {
    if (!seen.contains(video)) problems.add('$video: no English SRT');
  }
}

Map<String, Map<String, String>> _workCues() {
  final out = <String, Map<String, String>>{};
  final dir = Directory('data/i18n/work/subtitles');
  for (final file in dir.listSync().whereType<File>()) {
    if (!RegExp(r'part-\d+\.json$').hasMatch(file.path)) continue;
    final json = jsonDecode(file.readAsStringSync()) as Map;
    for (final entry in json.entries) {
      if (entry.key.startsWith('_')) continue;
      out[entry.key] = {
        for (final cue in (entry.value as Map).entries)
          '${cue.key}': '${cue.value}'.trim(),
      };
    }
  }
  return out;
}

class _Cue {
  final String timing;
  final String text;
  _Cue(this.timing, this.text);
}

Map<String, _Cue> _parse(String raw) {
  final text = raw.replaceFirst('\uFEFF', '');
  final result = <String, _Cue>{};
  for (final block in text.split(RegExp(r'\r?\n\r?\n+'))) {
    final lines = block.split(RegExp(r'\r?\n'));
    if (lines.length < 3) continue;
    final number = lines[0].trim();
    if (!RegExp(r'^\d+$').hasMatch(number)) continue;
    if (!lines[1].contains('-->')) continue;
    result[number] = _Cue(lines[1].trim(), lines.sublist(2).join(' ').trim());
  }
  return result;
}
