import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../request_builder/request_draft_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/widgets/json_view.dart';
import '../theme/widgets/status_badge.dart';
import 'history_provider.dart';

/// Per-endpoint response history: last N entries, most-recent-first.
/// Clicking one expands its stored status/headers/body inline, read-only,
/// clearly labeled "Historical" -- it never re-sends the request.
class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(requestDraftProvider);

    if (draft.id == draftEndpointId) {
      return const Center(
        key: Key('history-unsaved-state'),
        child: Text('Save this request to start recording history'),
      );
    }

    final asyncHistory = ref.watch(historyProvider(draft.id));

    return asyncHistory.when(
      data: (entries) {
        if (entries.isEmpty) {
          return const Center(
            key: Key('empty-history-state'),
            child: Text('No history yet — send a request'),
          );
        }
        final mostRecentFirst = entries.reversed.toList();
        return ListView.builder(
          key: const Key('history-list'),
          itemCount: mostRecentFirst.length,
          itemBuilder: (context, index) => _HistoryRow(entry: mostRecentFirst[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Failed to load history: $error')),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: ValueKey('history-row-${entry.id}'),
      title: Row(
        children: [
          if (entry.status != null) StatusBadge(statusCode: entry.status!),
          if (entry.error != null)
            const Text('Error', style: TextStyle(color: Colors.red)),
          const SizedBox(width: AppSpacing.sm),
          Text('${entry.elapsedMs}ms'),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry.timestamp.toLocal().toString(),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.history, size: 14, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Historical response — not live',
                    key: const Key('historical-label'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (entry.error != null)
                Text('Error: ${entry.error}')
              else
                JsonView(text: entry.body ?? ''),
            ],
          ),
        ),
      ],
    );
  }
}
