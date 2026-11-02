import 'package:flutter/material.dart';

import '../main.dart';

/// Full-bleed status strip under the app bar: batch download progress
/// (X/Y + line + Huỷ), the indeterminate "Đang huỷ…" state while a cancel is
/// settling, and determinate deletion progress.
///
/// It is deliberately chrome, not a card: no radius, no outline, no tint, so
/// it disappears into the black theme (pure black + one hairline) and reads as
/// part of the app bar everywhere else. Numbers come from the Dart stream, so
/// they stay truthful no matter what the native notification is doing.
class DownloadBanner extends StatelessWidget {
  const DownloadBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: App.downloads,
      builder: (context, _) {
        final dl = App.downloads;
        final theme = Theme.of(context);
        final dark = theme.brightness == Brightness.dark;

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
          color: dark
              ? theme.colorScheme.surfaceContainerLowest
              : theme.colorScheme.surfaceContainerLow,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant
                      .withValues(alpha: dark || dl.canceling ? 0.45 : 0.9),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      EdgeInsets.fromLTRB(16, 6, onCancel == null ? 16 : 6, 6),
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
                // Flush with the bottom edge: an accent line, no track.
                LinearProgressIndicator(
                  value: dl.canceling ? null : progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
