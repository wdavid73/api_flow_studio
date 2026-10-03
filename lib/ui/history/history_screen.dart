import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../collections/collections_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'all_history_provider.dart';
import 'day_label.dart';
import 'history_row.dart';

/// The History destination: every saved-request send, newest first, grouped
/// by day. Method, name and URL are looked up from the saved request; an
/// entry whose request was deleted is still listed as `Deleted request`.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(allHistoryProvider).value ?? const <HistoryEntry>[];
    final endpoints = ref.watch(collectionsProvider).value?.endpoints ?? const <Endpoint>[];
    final byId = {for (final e in endpoints) e.id: e};

    return Padding(
      key: const Key('history-screen'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('HISTORY', style: AppTypography.kicker.copyWith(color: AppColors.outline)),
          const SizedBox(height: AppSpacing.xs),
          Text('Request history', style: AppTypography.title),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    key: const Key('history-screen-empty'),
                    child: Text(
                      'No history yet — send a saved request.',
                      style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  )
                : _DayGroups(entries: entries, endpointsById: byId),
          ),
        ],
      ),
    );
  }
}

class _DayGroups extends StatelessWidget {
  const _DayGroups({required this.entries, required this.endpointsById});

  final List<HistoryEntry> entries;
  final Map<String, Endpoint> endpointsById;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final children = <Widget>[];
    String? currentDay;

    for (final entry in entries) {
      final day = dayLabel(entry.timestamp.toLocal(), now);
      if (day != currentDay) {
        currentDay = day;
        children.add(Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.xs, left: AppSpacing.sm),
          child: Text(day, style: AppTypography.kicker.copyWith(color: AppColors.outline)),
        ));
      }
      children.add(HistoryRow(entry: entry, endpoint: endpointsById[entry.endpointId]));
    }

    return ListView(children: children);
  }
}
