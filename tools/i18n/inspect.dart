// Diagnostic report for the English school work files.
//
// Run from the project root:
//   dart run tools/i18n/inspect.dart
//
// Writes data/i18n/inspect-school.txt with:
//   * duplicate video keys across subtitle parts
//   * per-video cue diffs (using the last occurrence, as the merge would)
//   * tag changes with both texts
//   * classification of Vietnamese/unchanged/number flags

import 'dart:convert';
import 'dart:io';

final _vi = RegExp(
  r'[àáảãạăằắẳẵặâầấẩẫậđèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵ]',
  caseSensitive: false,
);

void main() {
  final out = StringBuffer();
  final lessons = _lessons();
  final videos = _referencedVideos(lessons);

  // video -> list of (part, cues)
  final occurrences = <String, List<MapEntry<String, Map<String, String>>>>{};
  final dir = Directory('data/i18n/work/subtitles');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'part-\d+\.json$').hasMatch(f.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final name = _base(file.path);
    final json = _readJson(file) as Map;
    for (final e in json.entries) {
      if (e.key.startsWith('_')) continue;
      final cues = <String, String>{
        for (final c in (e.value as Map).entries) '${c.key}': '${c.value}',
      };
      occurrences.putIfAbsent(e.key, () => []).add(MapEntry(name, cues));
    }
  }

  out.writeln('== duplicate video keys ==');
  for (final e in occurrences.entries) {
    if (e.value.length > 1) {
      out.writeln('${e.key}: ${e.value.map((o) => o.key).join(', ')}');
      final first = e.value.first.value;
      for (final other in e.value.skip(1)) {
        final diff = <String>[];
        for (final cue in first.keys) {
          if (other.value[cue] != first[cue]) diff.add(cue);
        }
        for (final cue in other.value.keys) {
          if (!first.containsKey(cue)) diff.add('+$cue');
        }
        out.writeln('  ${other.key} differs in cues: ${diff.join(', ')}');
      }
    }
  }

  out.writeln('\n== cue diffs (last occurrence wins) ==');
  for (final video in videos) {
    final list = occurrences[video];
    if (list == null) continue;
    final src = _parseSrt(File('data/srt/$video.srt').readAsStringSync());
    final outCues = list.last.value;
    final missing = src.keys.where((k) => !outCues.containsKey(k)).toList();
    final extra = outCues.keys.where((k) => !src.containsKey(k)).toList();
    if (missing.isEmpty && extra.isEmpty) continue;
    out.writeln('$video (source ${src.length}, work ${outCues.length})');
    for (final cue in missing) {
      out.writeln('  missing $cue: ${src[cue]}');
    }
    for (final cue in extra) {
      out.writeln('  extra $cue: ${outCues[cue]}');
    }
  }

  out.writeln('\n== tag changes ==');
  for (final video in videos) {
    final list = occurrences[video];
    if (list == null) continue;
    final src = _parseSrt(File('data/srt/$video.srt').readAsStringSync());
    final outCues = list.last.value;
    for (final cue in src.keys) {
      final s = src[cue] ?? '';
      final o = outCues[cue];
      if (o == null) continue;
      if (!_sameTags(s, o)) {
        out.writeln('$video#$cue');
        out.writeln('  source: $s');
        out.writeln('  target: $o');
      }
    }
  }

  out.writeln('\n== VI flags with only marks/single letters ==');
  final viMarkOnly = <String>[];
  final viWords = <String>[];
  final viSentences = <String>[];
  final unchangedDigits = <String>[];
  final unchangedLetters = <String>[];
  var numberDrift = 0;
  final numberSamples = <String>[];

  for (final video in videos) {
    final list = occurrences[video];
    if (list == null) continue;
    final src = _parseSrt(File('data/srt/$video.srt').readAsStringSync());
    final outCues = list.last.value;
    for (final cue in src.keys) {
      final s = (src[cue] ?? '').trim();
      final o = (outCues[cue] ?? '').trim();
      if (o.isEmpty) continue;
      final label = '$video#$cue';
      if (_vi.hasMatch(o)) {
        if (!_hasAsciiLetters(o) && o.replaceAll(RegExp(r'\s'), '').length <= 3) {
          viMarkOnly.add('$label: $o');
        } else if (o.split(RegExp(r'\s+')).length <= 4) {
          viWords.add('$label: $s  ==>  $o');
        } else {
          viSentences.add('$label: $s  ==>  $o');
        }
      }
      if (o.toLowerCase() == s.toLowerCase() && s.length > 3) {
        if (RegExp(r'^[\d\s.,+\-=x×÷:()/<>%]+$').hasMatch(s)) {
          unchangedDigits.add('$label: $s');
        } else {
          unchangedLetters.add('$label: $s');
        }
      }
      if (!_sameNumbers(s, o)) {
        numberDrift++;
        numberSamples.add('$label: $s  ==>  $o');
      }
    }
  }

  out.writeln('mark-only VI: ${viMarkOnly.length}');
  for (final v in viMarkOnly.take(60)) {
    out.writeln('  $v');
  }
  out.writeln('word VI: ${viWords.length}');
  for (final v in viWords) {
    out.writeln('  $v');
  }
  out.writeln('sentence VI: ${viSentences.length}');
  for (final v in viSentences) {
    out.writeln('  $v');
  }
  out.writeln('unchanged numeric-only: ${unchangedDigits.length}');
  for (final v in unchangedDigits.take(40)) {
    out.writeln('  $v');
  }
  out.writeln('unchanged with words: ${unchangedLetters.length}');
  for (final v in unchangedLetters) {
    out.writeln('  $v');
  }
  out.writeln('number drift: $numberDrift');
  for (final v in numberSamples) {
    out.writeln('  $v');
  }

  // Titles and outlines: show the flagged text itself.
  out.writeln('\n== title flags ==');
  final titles = _readJson(File('data/i18n/work/titles.json')) as Map;
  final titleSrc = <String, String>{};
  for (final lesson in lessons) {
    titleSrc[lesson.id] = lesson.title;
  }
  for (final lesson in lessons) {
    final o = (titles[lesson.id] as String? ?? '').trim();
    final s = titleSrc[lesson.id] ?? '';
    if (_vi.hasMatch(o) || _hasLetters(s) && o.toLowerCase() == s.toLowerCase()) {
      out.writeln('${lesson.id}: $s  ==>  $o');
    }
  }

  out.writeln('\n== outline flags ==');
  final outlineJson = <String, List<String>>{};
  final outlineDir = Directory('data/i18n/work/outlines');
  for (final file in outlineDir.listSync().whereType<File>()) {
    if (!RegExp(r'part-\d+\.json$').hasMatch(file.path)) continue;
    final json = _readJson(file) as Map;
    for (final e in json.entries) {
      if (e.key.startsWith('_')) continue;
      outlineJson[e.key] = [for (final v in (e.value as List)) '$v'];
    }
  }
  for (final lesson in lessons) {
    final src = _sourceOutline(lesson.id);
    final outList = outlineJson[lesson.id];
    if (outList == null) continue;
    for (var i = 0; i < src.length && i < outList.length; i++) {
      final s = src[i];
      final o = outList[i];
      if (_vi.hasMatch(o)) {
        out.writeln('${lesson.id}[$i]: $s  ==>  $o');
      }
    }
  }

  final file = File('data/i18n/inspect-school.txt')
    ..parent.createSync(recursive: true);
  file.writeAsStringSync(out.toString());
  stdout.writeln('wrote ${file.path}');
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
      _Lesson(row['_id'] as String, (row['title'] as String? ?? '').trim()),
  ];
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

Set<String> _referencedVideos(List<_Lesson> lessons) {
  final set = <String>{};
  for (final lesson in lessons) {
    final file = File('data/json/tablecontent/${lesson.id}.json');
    if (!file.existsSync()) continue;
    final root = jsonDecode(file.readAsStringSync()) as Map;
    for (final row in (root['datas'] as List).cast<Map>()) {
      final video = (row['video'] as String? ?? '').trim();
      if (video.isNotEmpty && File('data/srt/$video.srt').existsSync()) {
        set.add(video);
      }
    }
  }
  return set;
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

bool _hasAsciiLetters(String s) => RegExp(r'[a-zA-Z]').hasMatch(s);

bool _hasLetters(String s) => RegExp(r'[a-zA-ZÀ-ỹ]').hasMatch(s);

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

bool _sameNumbers(String a, String b) {
  final na = RegExp(r'\d+').allMatches(a).map((m) => m.group(0)!).toList()..sort();
  final nb = RegExp(r'\d+').allMatches(b).map((m) => m.group(0)!).toList()..sort();
  if (na.length != nb.length) return false;
  for (var i = 0; i < na.length; i++) {
    if (na[i] != nb[i]) return false;
  }
  return true;
}
