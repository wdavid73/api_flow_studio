import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../collections/collections_provider.dart';
import '../shared/list_detail_layout.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'canvas/flow_canvas.dart';
import 'canvas/flow_toolbar.dart';
import 'canvas/step_panel.dart';
import 'flows_provider.dart';
import 'flows_transfer_actions.dart';
import '../projects/projects_provider.dart';
import '../../l10n/l10n.dart';

/// Which flow is currently shown in the right-hand builder. UI-only, not
/// persisted (same pattern as [selectedEnvironmentIdProvider]).
final selectedFlowIdProvider = StateProvider<String?>((ref) {
  ref.watch(activeProjectIdProvider);
  return null;
});

/// Which step of the selected flow is open in the side panel, if any. Starts
/// over when another flow is selected.
final selectedStepIndexProvider = StateProvider<int?>((ref) {
  ref.watch(selectedFlowIdProvider);
  return null;
});

/// The tab the side panel opens on: Step when a node is picked by hand, Run
/// after a run selected the step to look at.
final stepPanelTabProvider = StateProvider<StepPanelTab>((ref) {
  ref.watch(selectedFlowIdProvider);
  return StepPanelTab.step;
});

/// The "Flows" nav destination: a list of saved flows on the left; on the
/// right the selected flow's toolbar, its canvas of step nodes and, when a
/// step is selected, that step's side panel.
class FlowsScreen extends ConsumerWidget {
  const FlowsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncFlows = ref.watch(flowsProvider);
    final asyncCollections = ref.watch(collectionsProvider);

    if (asyncFlows.isLoading || asyncCollections.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final flowsError = asyncFlows.error;
    if (flowsError != null) {
      return Center(child: Text(context.l10n.commonFailedToLoad(context.l10n.flowsLoadWhat, flowsError)));
    }
    final flows = asyncFlows.value ?? const [];
    final endpoints = <String, Endpoint>{
      for (final e in asyncCollections.value?.endpoints ?? const <Endpoint>[]) e.id: e,
    };

    return ListDetailLayout(
      header: Consumer(
        builder: (context, ref, _) => ListPanelHeader(
          title: context.l10n.flowsKicker,
          actionLabel: context.l10n.flowsNew,
          actionKey: const Key('new-flow-button'),
          onAction: () async {
            final flow = await ref.read(flowsProvider.notifier).createFlow(context.l10n.flowsNewName);
            ref.read(selectedFlowIdProvider.notifier).state = flow.id;
          },
          trailing: [
            IconButton(
              key: const Key('import-flows-button'),
              tooltip: context.l10n.flowsImportTooltip,
              icon: const Icon(Icons.file_download_outlined, size: 18),
              onPressed: () => importFlows(context, ref),
            ),
            IconButton(
              key: const Key('export-flows-button'),
              tooltip: context.l10n.flowsExportTooltip,
              icon: const Icon(Icons.file_upload_outlined, size: 18),
              onPressed: () => exportFlows(context, ref),
            ),
          ],
        ),
      ),
      list: _FlowList(flows: flows),
      detail: Consumer(
        builder: (context, ref, _) {
          final selectedId = ref.watch(selectedFlowIdProvider);
          Flow? selected;
          for (final f in flows) {
            if (f.id == selectedId) {
              selected = f;
              break;
            }
          }
          if (selected == null) {
            return Center(
              key: Key('no-flow-selected'),
              child: Text(context.l10n.flowsSelectOrCreate),
            );
          }
          return _FlowDetail(flow: selected, endpoints: endpoints);
        },
      ),
    );
  }
}

class _FlowList extends ConsumerWidget {
  const _FlowList({required this.flows});

  final List<Flow> flows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedFlowIdProvider);

    if (flows.isEmpty) {
      return Center(
        key: Key('empty-flows-state'),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Text(context.l10n.flowsEmptyList),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      itemCount: flows.length,
      itemBuilder: (context, index) {
        final flow = flows[index];
        final isSelected = flow.id == selectedId;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Material(
            key: Key('flow-row-surface-${flow.id}'),
            color: isSelected ? AppColors.surfaceContainerHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: InkWell(
              key: ValueKey('flow-list-item-${flow.id}'),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              hoverColor: AppColors.surfaceContainer,
              onTap: () => ref.read(selectedFlowIdProvider.notifier).state = flow.id,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(flow.name, style: AppTypography.headlineSm, overflow: TextOverflow.ellipsis),
                          Text(
                            context.l10n.flowsStepCount(flow.steps.length),
                            style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: ValueKey('delete-flow-${flow.id}'),
                      tooltip: context.l10n.flowsDelete,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      onPressed: () async {
                        await ref.read(flowsProvider.notifier).deleteFlow(flow.id);
                        if (selectedId == flow.id) {
                          ref.read(selectedFlowIdProvider.notifier).state = null;
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FlowDetail extends ConsumerWidget {
  const _FlowDetail({required this.flow, required this.endpoints});

  final Flow flow;
  final Map<String, Endpoint> endpoints;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedStep = ref.watch(selectedStepIndexProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Keyed by flow: the name field takes its initial value only once.
        FlowToolbar(key: ValueKey('flow-toolbar-${flow.id}'), flow: flow, endpoints: endpoints),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: FlowCanvas(key: ValueKey('flow-canvas-${flow.id}'), flow: flow, endpoints: endpoints)),
              if (selectedStep != null && selectedStep < flow.steps.length) ...[
                const VerticalDivider(width: 1, color: AppColors.outlineVariant),
                SizedBox(
                  width: stepPanelWidth,
                  child: StepPanel(
                    flow: flow,
                    index: selectedStep,
                    endpoints: endpoints,
                    initialTab: ref.watch(stepPanelTabProvider),
                    onClose: () => ref.read(selectedStepIndexProvider.notifier).state = null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
