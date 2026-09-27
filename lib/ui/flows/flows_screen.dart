import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../collections/collections_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'add_step_picker.dart';
import 'flow_run_view_screen.dart';
import 'flows_provider.dart';
import 'step_card.dart';

/// Which flow is currently shown in the right-hand builder. UI-only, not
/// persisted (same pattern as [selectedEnvironmentIdProvider]).
final selectedFlowIdProvider = StateProvider<String?>((ref) => null);

/// The "Flows" nav destination: a list of saved flows on the left, the
/// selected flow's builder (name, step pipeline, add/remove/reorder) on
/// the right.
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
      return Center(child: Text('Failed to load flows: $flowsError'));
    }
    final flows = asyncFlows.value ?? const [];
    final endpoints = <String, Endpoint>{
      for (final e in asyncCollections.value?.endpoints ?? const <Endpoint>[]) e.id: e,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 260, child: _FlowList(flows: flows)),
        Expanded(
          child: Consumer(
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
                return const Center(
                  key: Key('no-flow-selected'),
                  child: Text('Select or create a flow to get started'),
                );
              }
              return _FlowBuilder(flow: selected, endpoints: endpoints);
            },
          ),
        ),
      ],
    );
  }
}

class _FlowList extends ConsumerWidget {
  const _FlowList({required this.flows});

  final List<Flow> flows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedFlowIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          key: const Key('new-flow-button'),
          onPressed: () async {
            final flow = await ref.read(flowsProvider.notifier).createFlow('New Flow');
            ref.read(selectedFlowIdProvider.notifier).state = flow.id;
          },
          icon: const Icon(Icons.add, size: 16),
          label: const Text('New flow'),
        ),
        Expanded(
          child: flows.isEmpty
              ? const Center(
                  key: Key('empty-flows-state'),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('No flows yet — create one to chain requests together.'),
                  ),
                )
              : ListView.builder(
                  itemCount: flows.length,
                  itemBuilder: (context, index) {
                    final flow = flows[index];
                    return ListTile(
                      key: ValueKey('flow-list-item-${flow.id}'),
                      selected: flow.id == selectedId,
                      title: Text(flow.name),
                      subtitle: Text('${flow.steps.length} steps'),
                      onTap: () => ref.read(selectedFlowIdProvider.notifier).state = flow.id,
                      trailing: IconButton(
                        key: ValueKey('delete-flow-${flow.id}'),
                        tooltip: 'Delete flow',
                        icon: const Icon(Icons.delete_outline, size: 16),
                        onPressed: () async {
                          await ref.read(flowsProvider.notifier).deleteFlow(flow.id);
                          if (selectedId == flow.id) {
                            ref.read(selectedFlowIdProvider.notifier).state = null;
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FlowBuilder extends ConsumerWidget {
  const _FlowBuilder({required this.flow, required this.endpoints});

  final Flow flow;
  final Map<String, Endpoint> endpoints;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(flowsProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      key: const Key('flow-name-field'),
                      initialValue: flow.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      decoration: const InputDecoration(border: InputBorder.none),
                      onChanged: (value) => notifier.renameFlow(flow.id, value),
                    ),
                  ),
                  OutlinedButton(
                    key: const Key('save-flow-button'),
                    onPressed: null, // saving is implicit on every edit; kept as a visual affordance
                    child: const Text('Save Flow'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    key: const Key('run-flow-button'),
                    onPressed: flow.steps.isEmpty
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => FlowRunViewScreen(flow: flow, endpoints: endpoints),
                              ),
                            ),
                    child: const Text('Run Flow'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: flow.steps.isEmpty
                ? const Center(
                    key: Key('empty-flow-state'),
                    child: Text('No steps yet — add a saved endpoint to get started'),
                  )
                : SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var index = 0; index < flow.steps.length; index++) ...[
                              if (index > 0)
                                const Center(
                                  child: Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 20,
                                    color: AppColors.outlineVariant,
                                  ),
                                ),
                              StepCard(
                                index: index,
                                step: flow.steps[index],
                                endpoint: endpoints[flow.steps[index].endpointId],
                                isFirst: index == 0,
                                isLast: index == flow.steps.length - 1,
                                onMoveUp: () => notifier.reorderStep(flow.id, index, index - 1),
                                onMoveDown: () => notifier.reorderStep(flow.id, index, index + 1),
                                onRemove: () => notifier.removeStep(flow.id, index),
                                onUpdateStep: (updated) =>
                                    notifier.updateStep(flow.id, index, updated),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          TextButton.icon(
            key: const Key('add-step-button'),
            onPressed: () async {
              final endpoint = await showAddStepPicker(context, ref);
              if (endpoint != null) {
                await notifier.addStep(flow.id, FlowStep(endpointId: endpoint.id));
              }
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add Next Step to Pipeline'),
          ),
        ],
      ),
    );
  }
}
