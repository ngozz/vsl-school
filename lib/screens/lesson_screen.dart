import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/lesson.dart';
import '../services/download_service.dart';
import '../widgets/download_dialogs.dart';
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

  /// False until the current segment is confirmed playable (on iOS this
  /// includes its download); the player slot shows a spinner meanwhile.
  bool _segmentReady = false;

  @override
  void initState() {
    super.initState();
    App.lessons.segments(widget.lesson.id).then((s) {
      if (!mounted) return;
      setState(() {
        _segments = s;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_selectSegment(0));
      });
    });
  }

  Set<String> get _videoNames => {for (final s in _segments) s.video};

  /// iOS: AVPlayer cannot play 200-only CDN streams, so a not-downloaded
  /// segment blocks on the lesson-download prompt, then waits for its video.
  Future<void> _selectSegment(int i) async {
    final seg = _segments[i];
    if (App.downloads.active && !kIsWeb && Platform.isIOS) {
      var ok = App.downloads.hasPlayableLocal(seg.video);
      if (!ok && !App.downloads.isBusy(seg.video)) {
        ok = await _promptLessonDownload() != null;
      }
      if (!mounted) return;
      if (!ok) {
        _snack('Cần tải bài học để phát trên iOS.');
        return;
      }
      if (!App.downloads.hasPlayableLocal(seg.video)) {
        final done = await App.downloads.waitFor(seg.video);
        if (!mounted) return;
        if (!done) {
          _snack('Tải video thất bại — thử lại.');
          return;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _index = i;
      _segmentReady = true;
    });
  }

  /// The same prompt/flow as the lesson download button. Returns the number
  /// of videos enqueued, 0 when nothing needed downloading, null when the
  /// user declined.
  Future<int?> _promptLessonDownload() async {
    final dl = App.downloads;
    final entries = <VideoEntry>[
      for (final n in _videoNames)
        if (!_isSafeToSkip(n))
          dl.entryFor(n) ?? VideoEntry(name: n, size: 0, sha256: ''),
    ];
    if (entries.isEmpty) return 0;
    final bytes = entries.fold(0, (a, e) => a + e.size);
    if (!await DownloadDialogs.confirmBatch(context, entries.length, bytes)) {
      return null;
    }
    if (!mounted) return null;
    if (!await DownloadDialogs.ensureNetworkOk(context, dl, bytes)) {
      return null;
    }
    if (!mounted) return null;
    return dl.enqueueAll(entries);
  }

  /// Appbar download button: same flow, with a confirmation snackbar.
  Future<void> _downloadLesson() async {
    final n = await _promptLessonDownload();
    if (!mounted) return;
    if (n == null) return;
    _snack(n == 0 ? 'Bài học đã được tải về máy.' : 'Đã bắt đầu tải $n video…');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _isSafeToSkip(String name) =>
      App.downloads.hasPlayableLocal(name) || App.downloads.isBusy(name);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lesson.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (App.downloads.active)
            AnimatedBuilder(
              animation: App.downloads,
              builder: (context, _) {
                if (_loading) return const SizedBox.shrink();
                final names = _videoNames;
                final done = App.downloads.allDownloaded(names);
                if (done) {
                  return const IconButton(
                    tooltip: 'Đã tải về máy',
                    icon: Icon(Icons.download_done,
                        color: Color(0xFF81C995)),
                    onPressed: null,
                  );
                }
                final progress = App.downloads.lessonProgress(names);
                if (progress > 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Center(
                      child: Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [
                            FontFeature.tabularFigures()
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return IconButton(
                  tooltip: 'Tải bài này về máy',
                  icon: const Icon(Icons.download_outlined),
                  onPressed: _downloadLesson,
                );
              },
            ),
        ],
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
                          child: !_segmentReady
                              ? const AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Center(
                                      child: CircularProgressIndicator()))
                              : LessonVideoPlayer(
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
              onTap: () => unawaited(_selectSegment(i)),
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