import 'package:flutter/material.dart';

import '../main.dart';

/// Full-bleed status strip under the app bar: batch download progress
/// (X/Y + line + Huỷ), the indeterminate "Đang huỷ…" state while a cancel is
/// settling, and determinate deletion progress.
///
/// It is deliberately chrome, not a card: no radius, no outline, no tint, and
/// it uses the same background as the app bar / scaffold, so the strip is one
/// continuous "frozen" area while the list scrolls beneath it. Content is
/// inset like the rest of the screen (20 px) and the progress line shares that
/// inset instead of bleeding to the edges.
class DownloadBanner extends StatelessWidget {
  const DownloadBanner({super.key});

  /// Same horizontal inset as the settings sheet and the page content.
  static const _inset = 20.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: App.downloads,
      builder: (context, _) {
        final dl = App.downloads;
        final theme = Theme.of(context);

        final String label;
        final IconData icon;
        double? progress;
        VoidCallback? onCancel;

        if (dl.deleteTotal > 0) {
          icon = Icons.delete_outline;
          label = 'Đang xoá ${dl.deleteDone}/${dl.deleteTotal} video…';
          progress = dl.deleteDone / dl.deleteTotal;
        } else if (dl.canceling) {
          // Indeterminate: the native cancel acks are still trickling in.
          icon = Icons.close;
          label = 'Đang huỷ tải…';
        } else {
          final busy = dl.busyBatchCount;
          final pending = dl.pendingBatchCount;
          final total = dl.batchTotal;
          if ((busy == 0 && pending == 0) || total == 0) {
            return const SizedBox.shrink();
          }
          final finished = (total - busy - pending).clamp(0, total);
          icon = Icons.cloud_download_outlined;
          label = 'Đang tải $finished/$total video…';
          progress = finished / total;
          onCancel = () => dl.cancelBatch();
        }

        return Material(
          // Identical to the app bar (see _common in main.dart), so the strip
          // never contrasts with the frozen area above it.
          color: theme.scaffoldBackgroundColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                // The cancel button carries 12 px of its own padding, so an
                // 8 px outer inset lands its label on the same 20 px line.
                padding: EdgeInsets.fromLTRB(
                    _inset, 6, onCancel == null ? _inset : 8, 6),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    if (onCancel != null)
                      TextButton(
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                        ),
                        child: const Text('Huỷ'),
                      ),
                  ],
                ),
              ),
              // Accent line, aligned with the content inset and with a little
              // air below it: reads as part of the page, not as an
              // edge-to-edge divider.
              Padding(
                padding: const EdgeInsets.fromLTRB(_inset, 0, _inset, 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: LinearProgressIndicator(
                    value: dl.canceling ? null : progress,
                    minHeight: 2,
                    backgroundColor: Colors.transparent,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
