/// Lesson data model.
///
/// Lesson id scheme: `{TOAN|TV}L{grade}KB{bai}` e.g. TOANL3KB01 — Toán,
/// grade 3, bài 1. A lesson is a sequence of video segments
/// (`{lesson}_{segNN}.mp4`) enumerated in `tablecontent/{lesson}.json`.
class Lesson {
  final String id; // e.g. TOANL3KB01
  final String title;
  final String titleEn; // English companion title (empty when missing)

  Lesson({required this.id, required this.title, this.titleEn = ''});

  Lesson withEnglish(String english) =>
      Lesson(id: id, title: title, titleEn: english.trim());

  /// Title to show for the current interface language.
  String displayTitle({required bool english}) =>
      english && titleEn.isNotEmpty ? titleEn : title;

  static Lesson fromMap(Map<String, dynamic> j) =>
      Lesson(id: j['_id'] as String, title: j['title'] as String);
}

/// One playing part of a lesson (one segment video + heading text).
class LessonSegment {
  final String content; // outline text
  final String contentEn; // English heading (empty when missing)
  final String level; // section numbering ("1")
  final String video; // e.g. TOANL3KB01_02

  LessonSegment({
    required this.content,
    this.contentEn = '',
    required this.level,
    required this.video,
  });

  LessonSegment withEnglish(String english) => LessonSegment(
        content: content,
        contentEn: english.trim(),
        level: level,
        video: video,
      );

  String displayContent({required bool english}) =>
      english && contentEn.isNotEmpty ? contentEn : content;

  static LessonSegment? fromJson(Map<String, dynamic> j) {
    final video = j['video'];
    if (video is! String || video.isEmpty) return null;
    return LessonSegment(
      content: (j['content'] as String?) ?? '',
      level: (j['level'] as String?) ?? '',
      video: video,
    );
  }
}

enum Subject { math, literature }
