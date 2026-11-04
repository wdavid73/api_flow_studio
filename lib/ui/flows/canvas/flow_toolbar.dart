import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/flows/flow_step_result.dart';
import '../../../engine/models/models.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../flow_run_provider.dart';
import '../flows_provider.dart';
import 'run_actions.dart';

/// Above the canvas: the flow's name (edited in place, saved as typed), the
/// summary of its last run and Run, which runs it right on the canvas.
class FlowToolbar extends ConsumerWidget {
  const FlowToolbar({super.key, required this.flow, required this.endpoints});

  final Flow flow;
  final Map<String, Endpoint> endpoints;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(flowRunProvider(flow.id));
    final results = run.results.whereType<FlowStepResult>().toList();
    int count(FlowStepStatus status) => results.where((r) => r.status == status).length;
    final totalMs = results.fold<int>(0, (sum, r) => sum + (r.response?.elapsedMs ?? 0));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              key: const Key('flow-name-field'),
              initialValue: flow.name,
              style: AppTypography.title,
              decoration: const InputDecoration(border: InputBorder.none, filled: false),
              onChanged: (value) => ref.read(flowsProvider.notifier).renameFlow(flow.id, value),
            ),
          ),
          if (results.isNotEmpty || run.running)
            // Gives way on a narrow window: the summary scrolls instead of overflowing.
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: AppSpacing.md),
                child: Row(
                  key: const Key('run-summary-strip'),
                  children: [
                    Text(context.l10n.runPassed(count(FlowStepStatus.success)), style: const TextStyle(color: AppColors.tertiary)),
                    const SizedBox(width: AppSpacing.md),
                    Text(context.l10n.runFailed(count(FlowStepStatus.failure)), style: const TextStyle(color: AppColors.error)),
                    const SizedBox(width: AppSpacing.md),
                    Text(context.l10n.runSkipped(count(FlowStepStatus.skipped)), style: const TextStyle(color: AppColors.outline)),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      context.l10n.commonTimeMs(totalMs),
                      key: const Key('run-summary-total'),
                      style: AppTypography.codeMd.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    if (run.running) ...[
                      const SizedBox(width: AppSpacing.md),
                      const SizedBox(
                        key: Key('run-in-progress-indicator'),
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          FilledButton(
            key: const Key('run-flow-button'),
            onPressed: flow.steps.isEmpty || run.running
                ? null
                : () => runAndShow(ref, flow.id, (notifier) => notifier.runAll(flow, endpoints)),
            child: Text(context.l10n.flowsRun),
          ),
        ],
      ),
    );
  }
}
