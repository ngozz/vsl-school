// One-off repairs for issues found by tools/i18n/validate.dart and
// tools/i18n/inspect.dart.
//
// Run from the vsl-school project root:
//   dart run tools/i18n/fix_work.dart
//
// Every repair is guarded: running the script twice changes nothing. The
// repairs are limited to lost/extra cues, shifted cue numbering, dropped inline
// tags and one mistranslated number. Each is documented next to its code.

import 'dart:convert';
import 'dart:io';

void main() {
  final report = <String>[];

  _fixVideo('part-01.json', 'TOANL1KB03_03', (cues) {
    // Source: "Có 3 hình tròn thêm 2 hình tròn" (3 circles + 2). The
    // translation said 4 circles.
    if (cues['6'] == 'There are 4 circles plus 2 circles. '
        'There are 5 circles in total') {
      cues['6'] = 'There are 3 circles plus 2 circles. '
          'There are 5 circles in total';
      return 'TOANL1KB03_03#6: 4 circles -> 3 circles';
    }
    return null;
  });

  _fixVideo('part-25.json', 'TVL2KB10_06', (cues) {
    // Source has two orange+bold highlighted choices.
    if (cues['6'] == 'Choose light bulb or electric fan?') {
      cues['6'] = 'Choose <color=orange><b>light bulb</b></color> or '
          '<color=orange><b>electric fan</b></color>?';
      return 'TVL2KB10_06#6: restored color/bold tags';
    }
    return null;
  });

  _fixVideo('part-39.json', 'TVL5KB02_02', (cues) {
    var changed = false;
    // "Cà Mau" was highlighted in the source in both cues.
    if (cues['2'] == 'Ca Mau is rainy monsoon land.') {
      cues['2'] = '<color=orange><b>Ca Mau</b></color> is rainy monsoon land.';
      changed = true;
    }
    if (cues['10'] == 'Living in Ca Mau, people must be very resourceful.') {
      cues['10'] = 'Living in <color=orange><b>Ca Mau</b></color>, '
          'people must be very resourceful.';
      changed = true;
    }
    return changed ? 'TVL5KB02_02#2,#10: restored color/bold tags' : null;
  });

  _fixVideo('part-37.json', 'TVL4KB15_02', (cues) {
    // Source cue 11 is "mới" (new) and cue 12 is "đẹp" (beautiful); the
    // translation merged them into cue 11.
    if (cues['11'] == 'new, beautiful' && !cues.containsKey('12')) {
      cues['11'] = 'new';
      cues['12'] = 'beautiful';
      return 'TVL4KB15_02#11,#12: split merged cue';
    }
    return null;
  });

  _fixVideo('part-29.json', 'TVL3KB09_03', (cues) {
    // Cues 11-13 were shifted up by one: cue 11 held the translation of 12,
    // cue 12 held the translation of 13, and cue 13 was missing.
    if (cues['11'] == 'Vietnamese has 2 ways.' &&
        cues['12'] == 'We study diligently. We study diligently.' &&
        !cues.containsKey('13')) {
      cues['11'] = 'Arrange the given words to form a sentence.';
      cues['12'] = 'Vietnamese has 2 ways.';
      cues['13'] = 'We study diligently. We diligently study.';
      return 'TVL3KB09_03#11-13: shifted cues restored';
    }
    return null;
  });

  _fixVideo('part-32.json', 'TVL3KB18_04', (cues) {
    // The whole video was shifted up by one: cue N held the translation of
    // source cue N+1, and the last source cue was missing.
    if (cues['1'] ==
            'Stilt house is type of house of ethnic groups living where?' &&
        cues.length == 25) {
      final shifted = <String, String>{
        '1': 'Please answer the questions below.',
      };
      for (final entry in cues.entries) {
        shifted['${int.parse(entry.key) + 1}'] = entry.value;
      }
      cues
        ..clear()
        ..addAll(shifted);
      return 'TVL3KB18_04: all cues shifted back by one (filled #1 and #26)';
    }
    return null;
  });

  _fixVideo('part-41.json', 'TVL5KB15_02', (cues) {
    // Source cue 25 contains both halves of the closing sentence; the
    // translation split the halves over cues 25-27 and added a 27th cue.
    if (cues.containsKey('27') &&
        cues['26'] == 'we will proudly say:' &&
        cues['27'] == 'My class monitor is great!') {
      cues['25'] = 'Now, if anyone asks about my class monitor, '
          'we will proudly say:';
      cues['26'] = 'My class monitor is great!';
      cues.remove('27');
      return 'TVL5KB15_02#25-27: merged split cue, removed extra cue';
    }
    return null;
  });

  _fixVideo('part-41.json', 'TVL5KB18_04', (cues) {
    // Source cue 17 was folded into cue 16; split it back.
    const joined = 'Children have the right to play and recreation; '
        'equal opportunities to participate in cultural, arts, physical '
        'education, sports, tourism activities suitable for age.';
    if (cues['16'] == joined && !cues.containsKey('17')) {
      cues['16'] = 'Children have the right to play and recreation;';
      cues['17'] = 'equal opportunities to participate in cultural, arts, '
          'physical education, sports, tourism activities suitable for '
          'their age.';
      return 'TVL5KB18_04#16,#17: split merged cue';
    }
    return null;
  });

  _fixVideo('part-40.json', 'TVL5KB05_04', (cues) {
    // "bê" (to carry) lost its diacritic; this is a Vietnamese vocabulary
    // lesson, so the word being taught must stay intact.
    if (cues['1'] == 'There are two words "be" and "vác".') {
      cues['1'] = 'There are two words "bê" and "vác".';
      return 'TVL5KB05_04#1: restored "bê"';
    }
    return null;
  });

  // The translator accidentally re-emitted the tail of part-41 as parts 42
  // and 43. Both are byte-for-byte redundant (verified by inspect.dart), so
  // dropping them keeps exactly one copy of every video.
  for (final name in ['part-42.json', 'part-43.json']) {
    final file = File('data/i18n/work/subtitles/$name');
    if (file.existsSync()) {
      file.deleteSync();
      report.add('$name: removed duplicate part');
    }
  }

  if (report.isNotEmpty) {
    for (final line in report) {
      stdout.writeln(line);
    }
  }
}

void _fixVideo(
  String part,
  String video,
  String? Function(Map<String, String> cues) fix,
) {
  final file = File('data/i18n/work/subtitles/$part');
  final root = _readJson(file) as Map<String, dynamic>;
  final raw = root[video];
  if (raw is! Map) {
    stderr.writeln('$part: $video not found');
    return;
  }
  final cues = <String, String>{
    for (final entry in raw.entries) '${entry.key}': '${entry.value}',
  };
  final message = fix(cues);
  if (message == null) return;
  root[video] = cues;
  _writeJson(file, root);
  stdout.writeln(message);
}

dynamic _readJson(File file) {
  var text = file.readAsStringSync().replaceFirst('\uFEFF', '').trim();
  if (text.startsWith('```')) {
    text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\r?\n'), '');
    text = text.replaceFirst(RegExp(r'\r?\n```\s*$'), '');
  }
  return jsonDecode(text);
}

void _writeJson(File file, Object json) {
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));
}
