import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../main.dart';
import '../services/download_service.dart';

/// Shared confirmations for the download & update UX:
/// large-batch warning → Wi-Fi check → explicit mobile-data confirmation.
abstract final class DownloadDialogs {
  /// Wi-Fi fast-path; on mobile data shows the warning once per app session
  /// (the flag lives on [DownloadService] and resets on app start).
  static Future<bool> ensureNetworkOk(
      BuildContext context, DownloadService dl, int bytes) async {
    if (await dl.onWifi()) return true;
    if (dl.mobileDataConfirmedThisSession) return true;
    if (!context.mounted) return false;
    if (!(await confirmMobileData(context, bytes))) return false;
    dl.mobileDataConfirmedThisSession = true;
    return true;
  }

  /// "Xoá tất cả dữ liệu đã tải?" — the cleanup confirmation.
  static Future<bool> confirmDeleteAll(
      BuildContext context, DownloadService dl) async {
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.deleteTitle),
            content: Text(
                l.deleteBody(dl.downloadedCount, _fmtBytes(dl.downloadedBytes))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.delete),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// iOS: blocks opening a lesson until its videos are on the device.
  /// Decision → live progress popup (stays on the home screen) → true when
  /// every entry has a verified local copy. Cancelling cancels the in-flight
  /// tasks (downloaded copies are kept).
  static Future<bool> ensureLessonDownloaded(BuildContext context,
      DownloadService dl, List<VideoEntry> entries) async {
    final remaining = [
      for (final e in entries)
        if (!dl.hasPlayableLocal(e.name)) e,
    ];
    if (remaining.isEmpty) return true;
    final bytes = remaining.fold(0, (a, e) => a + e.size);
    if (!await confirmBatch(context, remaining.length, bytes)) return false;
    if (!context.mounted) return false;
    if (!await ensureNetworkOk(context, dl, bytes)) return false;
    if (!context.mounted) return false;
    dl.enqueueAll(remaining);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LessonProgressDialog(dl: dl, entries: remaining),
    );
    return result ?? false;
  }

  /// "Sẽ tải N video (~X MB)" — the 3 GB-class warning before download-all.
  static Future<bool> confirmBatch(
      BuildContext context, int fileCount, int bytes) async {
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.batchTitle),
            content: Text(l.batchBody(fileCount, _fmtBytes(bytes))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.later),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.download),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Second gate when no Wi-Fi is visible: keep bytes flowing consciously.
  static Future<bool> confirmMobileData(
      BuildContext context, int bytes) async {
    final l = context.l10n;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.noWifiTitle),
            content: Text(l.noWifiBody(_fmtBytes(bytes))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.continueLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// The dismissible startup prompt: per-lesson diffs, [Cập nhật] applies.
  static Future<void> showUpdatePrompt(
      BuildContext context, List<LessonDiff> diffs) async {
    final l = context.l10n;
    final totalBytes = diffs.fold(0, (a, d) => a + d.bytes);
    final totalFiles = diffs.fold(0, (a, d) => a + d.changed.length);
    // Resolve the messenger before the dialog closes: looking it up from the
    // dialog's own (then deactivated) context is unsafe.
    final messenger = ScaffoldMessenger.of(context);
    String detailOf(LessonDiff d) => [
          if (d.changed.isNotEmpty) l.updateChanged(d.changed.length),
          if (d.removed.isNotEmpty) l.updateRemoved(d.removed.length),
        ].join(', ');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.new_releases_outlined),
        title: Text(l.updateTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final d in diffs.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                    l.updateLessonLine(
                        d.lesson.isEmpty ? l.updateOtherGroup : d.lesson,
                        detailOf(d)),
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            if (diffs.length > 4)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l.updateMore(diffs.length - 4),
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            const SizedBox(height: 6),
            Text(
                l.updateTotal(totalFiles, _fmtBytes(totalBytes)),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              App.updates.dismissedThisSession = true;
              Navigator.pop(context);
            },
            child: Text(l.later),
          ),
          FilledButton(
            onPressed: () {
              App.downloads
                  .enqueueAll(diffs.expand((d) => d.changed).toList());
              App.updates.dismissedThisSession = true;
              Navigator.pop(context);
              messenger.showSnackBar(
                  SnackBar(content: Text(l.updateStarted(totalFiles))));
            },
            child: Text(l.update),
          ),
        ],
      ),
    );
  }

  static String _fmtBytes(int b) {
    if (b <= 0) return '0 B';
    final mb = b / 1048576;
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '${mb.round()} MB';
  }
}

/// Live progress for the iOS lesson-download gate: X/Y video, MB counters
/// and a bar. Auto-closes when every entry has a verified local copy;
/// the Huỷ button cancels in-flight tasks (downloaded copies are kept).
class _LessonProgressDialog extends StatefulWidget {
  final DownloadService dl;
  final List<VideoEntry> entries;

  const _LessonProgressDialog({required this.dl, required this.entries});

  @override
  State<_LessonProgressDialog> createState() => _LessonProgressDialogState();
}

class _LessonProgressDialogState extends State<_LessonProgressDialog> {
  bool _closed = false;

  void _finish(bool ok) {
    if (_closed) return;
    _closed = true;
    // _finish runs from build when the last copy lands; popping the route
    // during build is illegal, so defer it to after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(ok);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AnimatedBuilder(
      animation: widget.dl,
      builder: (context, _) {
        final entries = widget.entries;
        final allDone = entries.every((e) => widget.dl.hasPlayableLocal(e.name));
        if (allDone) _finish(true);
        final total = entries.fold(0, (a, e) => a + e.size);
        var doneBytes = 0;
        var doneCount = 0;
        for (final e in entries) {
          final done = widget.dl.hasPlayableLocal(e.name);
          if (done) doneCount++;
          final p =
              done ? 1.0 : widget.dl.progressOf(e.name).clamp(0.0, 1.0);
          doneBytes += (e.size * p).round();
        }
        return AlertDialog(
          title: Text(l.lessonDownloadTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  l.lessonProgress(doneCount, entries.length,
                      DownloadDialogs._fmtBytes(doneBytes),
                      DownloadDialogs._fmtBytes(total)),
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                  value: total == 0 ? null : doneBytes / total),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _closed = true;
                widget.dl
                    .cancelTasks(entries.map((e) => e.name));
                Navigator.of(context).pop(false);
              },
              child: Text(l.cancel),
            ),
          ],
        );
      },
    );
  }
}
