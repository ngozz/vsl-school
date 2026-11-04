import 'package:video_player/video_player.dart';

/// Closed captions that prefer English and fall back to Vietnamese.
///
/// Both files must come from the same source SRT (same cue count and order),
/// which is exactly how `tools/i18n/merge.dart` writes `data/srt_en/`. A
/// missing, empty, or out-of-sync English file falls back to Vietnamese only,
/// so the player never loses the existing captions. The two languages are
/// never shown together.
class PreferredCaptionFile extends ClosedCaptionFile {
  final String vietnamese;
  final String? english;
  List<Caption>? _cache;

  PreferredCaptionFile(this.vietnamese, this.english);

  @override
  List<Caption> get captions {
    final cached = _cache;
    if (cached != null) return cached;

    final vi = SubRipCaptionFile(vietnamese).captions;
    final enText = english;
    if (enText == null || enText.trim().isEmpty) return _cache = vi;

    final en = SubRipCaptionFile(enText).captions;
    if (vi.isEmpty) return _cache = en;
    if (en.length != vi.length) return _cache = vi;

    return _cache = [
      for (var i = 0; i < vi.length; i++)
        Caption(
          number: vi[i].number,
          start: vi[i].start,
          end: vi[i].end,
          text: en[i].text.trim().isEmpty ? vi[i].text : en[i].text,
        ),
    ];
  }
}
