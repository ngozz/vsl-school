// Dumps source SRT cues and the translated work cues for a video.
//
// Usage:
//   dart run tools/i18n/dump_srt.dart TVL3KB09_03 TVL3KB18_04

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final out = StringBuffer();
  for (final video in args) {
    out.writeln('===== $video =====');
    final src = _parseSrt(File('data/srt/$video.srt').readAsStringSync());
    final tr = _translation(video);
    final keys = <String>{...src.keys, ...tr.keys}.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    for (final k in keys) {
      final marker = tr.containsKey(k) ? ' ' : '!';
      out.writeln('$marker#$k');
      out.writeln('  VI: ${src[k] ?? "<none>"}');
      out.writeln('  EN: ${tr[k] ?? "<none>"}');
    }
  }
  final file = File('data/i18n/dump-srt.txt')
    ..parent.createSync(recursive: true);
  file.writeAsStringSync(out.toString());
  stdout.writeln('wrote ${file.path}');
}

Map<String, String> _translation(String video) {
  final dir = Directory('data/i18n/work/subtitles');
  for (final file in dir.listSync().whereType<File>()) {
    if (!RegExp(r'part-\d+\.json$').hasMatch(file.path)) continue;
    final json = jsonDecode(
      file.readAsStringSync().replaceFirst('\uFEFF', '').trim(),
    ) as Map;
    for (final e in json.entries) {
      if (e.key == video) {
        return {
          for (final c in (e.value as Map).entries) '${c.key}': '${c.value}',
        };
      }
    }
  }
  return const {};
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
