import 'package:flutter/material.dart';

import '../../engine/models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/widgets/json_view.dart';
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
    required this.onUpdateStep,
  });

  final int index;
  final FlowStep step;
  final Endpoint? endpoint;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;
  final ValueChanged<FlowStep> onUpdateStep;

  @override
  Widget build(BuildContext context) {
    final extractEntries = step.extract.entries.toList();

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
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  foregroundColor: AppColors.onSurface,
                  child: Text('${index + 1}', style: AppTypography.codeSm),
                ),
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
                if (isLast)
                  Container(
                    key: ValueKey('terminal-badge-$index'),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                    margin: const EdgeInsets.only(right: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      'TERMINAL',
                      style: AppTypography.badgeMono.copyWith(color: AppColors.onSurfaceVariant),
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
                  style: AppTypography.codeSm.copyWith(color: AppColors.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (endpoint != null && _jsonBodyOf(endpoint!) != null)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PAYLOAD TEMPLATE',
                      style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      key: ValueKey('payload-template-$index'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: JsonView(text: _jsonBodyOf(endpoint!)!),
                    ),
                  ],
                ),
              ),
            const Divider(height: AppSpacing.lg * 2),
            Text('Extract Output Variables', style: Theme.of(context).textTheme.labelMedium),
            for (var i = 0; i < extractEntries.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('extract-name-$index-$i'),
                        initialValue: extractEntries[i].key,
                        decoration: const InputDecoration(hintText: 'variable_name', isDense: true),
                        onChanged: (name) {
                          final next = <String, String>{};
                          for (final e in extractEntries) {
                            next[e.key == extractEntries[i].key ? name : e.key] = e.value;
                          }
                          onUpdateStep(step.copyWith(extract: next));
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: Text('←'),
                    ),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        key: ValueKey('extract-path-$index-$i'),
                        initialValue: extractEntries[i].value,
                        decoration:
                            const InputDecoration(hintText: 'response.body.x.y', isDense: true),
                        onChanged: (path) {
                          final next = <String, String>{};
                          for (final e in extractEntries) {
                            next[e.key] = e.key == extractEntries[i].key ? path : e.value;
                          }
                          onUpdateStep(step.copyWith(extract: next));
                        },
                      ),
                    ),
                    IconButton(
                      key: ValueKey('remove-extract-$index-$i'),
                      icon: const Icon(Icons.close, size: 14),
                      onPressed: () {
                        final next = {...step.extract}..remove(extractEntries[i].key);
                        onUpdateStep(step.copyWith(extract: next));
                      },
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              key: ValueKey('add-extract-$index'),
              onPressed: () {
                var name = 'variable';
                var suffix = 1;
                while (step.extract.containsKey(name)) {
                  name = 'variable_$suffix';
                  suffix++;
                }
                onUpdateStep(step.copyWith(extract: {...step.extract, name: ''}));
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add extracted variable'),
            ),
            const Divider(height: AppSpacing.lg * 2),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('assert-field-$index'),
                    initialValue: step.assertField ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Assert field (optional)',
                      hintText: 'response.status',
                      isDense: true,
                    ),
                    onChanged: (value) => onUpdateStep(
                      step.copyWith(assertField: value.isEmpty ? null : value),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('assert-expected-$index'),
                    initialValue: step.assertExpected ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Expected value',
                      hintText: '200',
                      isDense: true,
                    ),
                    onChanged: (value) => onUpdateStep(
                      step.copyWith(assertExpected: value.isEmpty ? null : value),
                    ),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              key: ValueKey('stop-on-failure-$index'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Stop on failure'),
              value: step.stopOnFailure,
              onChanged: (value) => onUpdateStep(step.copyWith(stopOnFailure: value)),
            ),
          ],
        ),
      ),
    );
  }

  /// The endpoint's raw JSON body text, or null if it has no body / a
  /// non-JSON (form-urlencoded) body -- used for the read-only "Payload
  /// Template" preview, per Task 5.4b's original (never-built) note.
  String? _jsonBodyOf(Endpoint endpoint) => endpoint.body.when(
        none: () => null,
        json: (raw) => raw.trim().isEmpty ? null : raw,
        formUrlEncoded: (_) => null,
      );
}
