import 'package:flutter/material.dart';

import '../main.dart';
import '../models/lesson.dart';
import '../widgets/lesson_video_player.dart';

/// One lesson: video player on top, clickable segment outline below.
class LessonScreen extends StatefulWidget {
  final Lesson lesson;
  const LessonScreen({super.key, required this.lesson});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  List<LessonSegment> _segments = const [];
  int _index = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    App.lessons.segments(widget.lesson.id).then((s) {
      if (!mounted) return;
      setState(() {
        _segments = s;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _segments.isEmpty
              ? Center(
                  child: Text('Bài học chưa có nội dung',
                      style: theme.textTheme.bodyLarge))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: LessonVideoPlayer(
                            videoAsset:
                                'data/videos/${_segments[_index].video}.mp4',
                            captionAsset:
                                'data/srt/${_segments[_index].video}.srt',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(child: _outlineList(theme)),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _outlineList(ThemeData theme) {
    return ListView.builder(
      itemCount: _segments.length,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemBuilder: (context, i) {
        final sel = i == _index;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Material(
            color: sel
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _index = i),
              child: Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: sel
                            ? theme.colorScheme.primary
                            : theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: Text('${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: sel
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          )),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _segments[i].content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (sel)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Icon(Icons.play_arrow_rounded,
                            color: theme.colorScheme.primary),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}