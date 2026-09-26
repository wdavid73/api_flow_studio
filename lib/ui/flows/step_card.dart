import 'package:flutter/material.dart';

import '../../engine/models/models.dart';
import '../theme/app_spacing.dart';
import '../theme/widgets/method_badge.dart';

/// One step in the flow builder's vertical pipeline. [endpoint] is null
/// when the step's endpointId no longer resolves to a saved endpoint
/// (e.g. it was deleted from the collection) -- shown as a warning rather
/// than crashing.
class StepCard extends StatelessWidget {
  const StepCard({
    super.key,
    required this.index,
    required this.step,
    required this.endpoint,
    required this.isFirst,
    required this.isLast,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final int index;
  final FlowStep step;
  final Endpoint? endpoint;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('step-card-$index'),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 12, child: Text('${index + 1}')),
                const SizedBox(width: AppSpacing.sm),
                if (endpoint != null) MethodBadge(method: endpoint!.method),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    endpoint?.name ?? 'Missing endpoint (${step.endpointId})',
                    overflow: TextOverflow.ellipsis,
                    style: endpoint == null
                        ? TextStyle(color: Theme.of(context).colorScheme.error)
                        : null,
                  ),
                ),
                IconButton(
                  key: ValueKey('move-step-up-$index'),
                  icon: const Icon(Icons.arrow_upward, size: 16),
                  onPressed: isFirst ? null : onMoveUp,
                ),
                IconButton(
                  key: ValueKey('move-step-down-$index'),
                  icon: const Icon(Icons.arrow_downward, size: 16),
                  onPressed: isLast ? null : onMoveDown,
                ),
                IconButton(
                  key: ValueKey('remove-step-$index'),
                  icon: const Icon(Icons.delete_outline, size: 16),
                  onPressed: onRemove,
                ),
              ],
            ),
            if (endpoint != null)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: AppSpacing.xs),
                child: Text(
                  endpoint!.url,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
