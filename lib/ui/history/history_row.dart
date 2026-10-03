import 'package:flutter/material.dart';

import '../../engine/models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/widgets/method_badge.dart';
import '../theme/widgets/status_badge.dart';
import 'day_label.dart';

/// One send in the global history: the request it belonged to (method, name,
/// URL; or `Deleted request` when that request no longer exists), then the
/// outcome (status or `Error`), elapsed time and the hour.
class HistoryRow extends StatelessWidget {
  const HistoryRow({super.key, required this.entry, required this.endpoint});

  final HistoryEntry entry;

  /// The saved request this entry belongs to, or null if it was deleted.
  final Endpoint? endpoint;

  @override
  Widget build(BuildContext context) {
    final endpoint = this.endpoint;
    final muted = AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant);

    return Padding(
      key: ValueKey('history-entry-${entry.id}'),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(width: 54, child: endpoint == null ? null : MethodBadge(method: endpoint.method)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  endpoint?.name ?? 'Deleted request',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd.copyWith(
                    color: endpoint == null ? AppColors.onSurfaceVariant : AppColors.onSurface,
                    fontStyle: endpoint == null ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                if (endpoint != null)
                  Text(
                    endpoint.url,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.codeSm.copyWith(color: AppColors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (entry.error != null || entry.status == null)
            Text('Error', style: AppTypography.codeMd.copyWith(color: AppColors.error))
          else
            StatusBadge(statusCode: entry.status!),
          const SizedBox(width: AppSpacing.md),
          Text('${entry.elapsedMs} ms', style: muted),
          const SizedBox(width: AppSpacing.md),
          Text(formatTime(entry.timestamp.toLocal()), style: muted),
        ],
      ),
    );
  }
}
