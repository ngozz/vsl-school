import 'package:flutter/material.dart';

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
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xoá dữ liệu đã tải'),
            content: Text(
                'Xoá ${dl.downloadedCount} video đã tải '
                '(~${_fmtBytes(dl.downloadedBytes)})? '
                'Video sẽ phát trực tuyến từ CDN.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xoá'),
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
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Tải xuống nội dung'),
            content: Text(
                'Sẽ tải $fileCount video (~${_fmtBytes(bytes)}).\n'
                'Nên dùng Wi-Fi. Tiếp tục?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Tải'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Second gate when no Wi-Fi is visible: keep bytes flowing consciously.
  static Future<bool> confirmMobileData(
      BuildContext context, int bytes) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Không thấy Wi-Fi'),
            content: Text(
                'Thiết bị đang dùng dữ liệu di động. '
                'Tiếp tục tải (~${_fmtBytes(bytes)})?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Tiếp tục'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// The dismissible startup prompt: per-lesson diffs, [Cập nhật] applies.
  static Future<void> showUpdatePrompt(
      BuildContext context, List<LessonDiff> diffs) async {
    final totalBytes = diffs.fold(0, (a, d) => a + d.bytes);
    final totalFiles = diffs.fold(0, (a, d) => a + d.changed.length);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.new_releases_outlined),
        title: const Text('Có bản cập nhật nội dung'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final d in diffs.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                    '${d.lesson}: '
                    '${d.changed.isNotEmpty ? '${d.changed.length} video thay đổi' : ''}'
                    '${d.changed.isNotEmpty && d.removed.isNotEmpty ? ', ' : ''}'
                    '${d.removed.isNotEmpty ? '${d.removed.length} video bỏ' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            if (diffs.length > 4)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('… và ${diffs.length - 4} bài khác',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            const SizedBox(height: 6),
            Text(
                'Tổng: $totalFiles video (~${_fmtBytes(totalBytes)}). '
                'Cập nhật để dùng bản mới nhất.',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              App.updates.dismissedThisSession = true;
              Navigator.pop(context);
            },
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () {
              App.downloads
                  .enqueueAll(diffs.expand((d) => d.changed).toList());
              App.updates.dismissedThisSession = true;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Đang tải lại $totalFiles video cập nhật…')));
            },
            child: const Text('Cập nhật'),
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
    Navigator.of(context).pop(ok);
  }

  @override
  Widget build(BuildContext context) {
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
          title: const Text('Đang tải bài học'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '$doneCount/${entries.length} video — '
                  '${DownloadDialogs._fmtBytes(doneBytes)} / ${DownloadDialogs._fmtBytes(total)}',
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
              child: const Text('Huỷ'),
            ),
          ],
        );
      },
    );
  }
}
