import 'package:flutter/material.dart';

import '../main.dart';

/// Persistent in-app status chip at the top of the home screen: batch
/// download progress (X/Y + bar + cancel) and deletion progress. Always
/// truthful — the numbers come from the Dart stream, not the native
/// notification accounting.
class DownloadBanner extends StatelessWidget {
  const DownloadBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: App.downloads,
      builder: (context, _) {
        final dl = App.downloads;
        final theme = Theme.of(context);

        // Deletion runs exclusively while this banner is visible.
        if (dl.deleteTotal > 0) {
          return _chip(
            context,
            theme,
            icon: Icons.delete_outline,
            label: 'Đang xoá ${dl.deleteDone}/${dl.deleteTotal} video…',
            progress:
                dl.deleteTotal == 0 ? null : dl.deleteDone / dl.deleteTotal,
          );
        }
        final busy = dl.busyBatchCount;
        final pending = dl.pendingBatchCount;
        final total = dl.batchTotal;
        if ((busy == 0 && pending == 0) || total == 0) {
          return const SizedBox.shrink();
        }
        final finished = (total - busy - pending).clamp(0, total);
        return _chip(
          context,
          theme,
          icon: Icons.cloud_download_outlined,
          label: 'Đang tải $finished/$total video…',
          progress: finished / total,
          onCancel: () => dl.cancelBatch(),
        );
      },
    );
  }

  Widget _chip(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required String label,
    double? progress,
    VoidCallback? onCancel,
  }) {
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                      value: progress, minHeight: 4, borderRadius: BorderRadius.circular(2)),
                ],
              ),
            ),
            if (onCancel != null)
              IconButton(
                tooltip: 'Huỷ tải',
                icon: const Icon(Icons.close, size: 18),
                onPressed: onCancel,
              ),
          ],
        ),
      ),
    );
  }
}
