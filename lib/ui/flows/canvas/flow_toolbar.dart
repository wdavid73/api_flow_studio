import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/models/models.dart';
import '../../../l10n/l10n.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../flow_run_view_screen.dart';
import '../flows_provider.dart';

/// Above the canvas: the flow's name (edited in place, saved as typed) and Run.
class FlowToolbar extends ConsumerWidget {
  const FlowToolbar({super.key, required this.flow, required this.endpoints});

  final Flow flow;
  final Map<String, Endpoint> endpoints;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          FilledButton(
            key: const Key('run-flow-button'),
            onPressed: flow.steps.isEmpty
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => FlowRunViewScreen(flow: flow, endpoints: endpoints)),
                    ),
            child: Text(context.l10n.flowsRun),
          ),
        ],
      ),
    );
  }
}
