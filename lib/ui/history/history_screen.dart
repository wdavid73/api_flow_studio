import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../collections/collections_provider.dart';
import '../request_builder/request_draft_provider.dart';
import '../shell/app_destination.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../environments/environments_provider.dart' show jsonStoreProvider;
import '../shell/app_toast.dart';
import '../shell/header_ghost_button.dart';
import 'all_history_provider.dart';
import 'day_label.dart';
import 'history_provider.dart';
import 'history_row.dart';
import '../projects/projects_provider.dart';

/// Text typed in the History search field. UI-only state, not persisted.
final historySearchQueryProvider = StateProvider<String>((ref) {
  ref.watch(activeProjectIdProvider);
  return '';
});

/// Whether [entry] matches the lowercase [query]: its request's name, method
/// or URL contains it (a deleted request matches on its `Deleted request`
/// label). An empty query matches everything.
bool _matches(HistoryEntry entry, Endpoint? endpoint, String query) {
  if (query.isEmpty) return true;
  final fields = endpoint == null
      ? ['deleted request']
      : [endpoint.name, endpoint.method, endpoint.url];
  return fields.any((f) => f.toLowerCase().contains(query));
}

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
    final query = ref.watch(historySearchQueryProvider).trim().toLowerCase();
    final visible = [for (final e in entries) if (_matches(e, byId[e.endpointId], query)) e];

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
          if (entries.isNotEmpty) ...[
            Row(
              children: [
                SizedBox(
                  width: 360,
                  child: TextField(
                    key: const Key('history-search-field'),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Filter history…',
                      prefixIcon: Icon(Icons.search, size: 16),
                    ),
                    onChanged: (value) => ref.read(historySearchQueryProvider.notifier).state = value,
                  ),
                ),
                const Spacer(),
                HeaderGhostButton(
                  key: const Key('clear-history-button'),
                  label: 'Clear history',
                  onPressed: () => _confirmClear(context, ref),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Expanded(
            child: entries.isEmpty
                ? Center(
                    key: const Key('history-screen-empty'),
                    child: Text(
                      'No history yet — send a saved request.',
                      style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  )
                : visible.isEmpty
                    ? Center(
                        key: const Key('history-no-results'),
                        child: Text(
                          'Nothing matches that search.',
                          style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      )
                    : _DayGroups(entries: visible, endpointsById: byId),
          ),
        ],
      ),
    );
  }
}

/// Asks before deleting the history of the active project, then does it.
Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
  final project = ref.read(projectsProvider).active;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Clear the history of "${project.name}"?'),
      content: const Text(
        'This deletes every saved response of this project. '
        'Your requests, environments and flows are not touched.',
      ),
      actions: [
        TextButton(
          key: const Key('clear-history-cancel-button'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('clear-history-confirm-button'),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  await ref.read(jsonStoreProvider).clearHistory();
  ref.invalidate(allHistoryProvider);
  ref.invalidate(historyProvider);
  showToast(ref, 'History cleared');
}

class _DayGroups extends ConsumerWidget {
  const _DayGroups({required this.entries, required this.endpointsById});

  final List<HistoryEntry> entries;
  final Map<String, Endpoint> endpointsById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      final endpoint = endpointsById[entry.endpointId];
      children.add(HistoryRow(
        entry: entry,
        endpoint: endpoint,
        onTap: endpoint == null
            ? null
            : () {
                ref.read(requestDraftProvider.notifier).loadEndpoint(endpoint);
                ref.read(selectedDestinationProvider.notifier).state = AppDestination.workspace;
              },
      ));
    }

    return ListView(children: children);
  }
}
