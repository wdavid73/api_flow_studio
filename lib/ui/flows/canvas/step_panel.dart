import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/flows/flow_step_result.dart';
import '../../../engine/flows/input_origin.dart';
import '../../../engine/flows/response_fields.dart';
import '../../../engine/flows/step_inputs.dart';
import '../../../engine/models/models.dart';
import '../../../l10n/l10n.dart';
import '../../environments/environments_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../theme/widgets/method_badge.dart';
import '../add_step_picker.dart';
import '../assertions_editor.dart';
import '../extracts_editor.dart';
import '../flow_run_provider.dart';
import '../flows_provider.dart';
import '../response_tree.dart';
import '../run_step_inspector.dart';
import '../step_response.dart';
import 'origin_label.dart';
import 'run_actions.dart';

/// Width of the side panel next to the canvas.
const double stepPanelWidth = 400;

enum StepPanelTab { step, response, run }

/// What does not fit in a step's node, next to the canvas: the step's inputs
/// and what it extracts, its assertions and stop-on-failure (tab Step), its
/// whole last response (tab Response) and the result of its last run (tab Run,
/// only when there is one). Every edit is saved at once, like everywhere else
/// in the flows screen.
class StepPanel extends ConsumerStatefulWidget {
  const StepPanel({
    super.key,
    required this.flow,
    required this.index,
    required this.endpoints,
    required this.onClose,
    this.initialTab = StepPanelTab.step,
    this.onFieldTap,
  });

  final Flow flow;
  final int index;
  final Map<String, Endpoint> endpoints;
  final VoidCallback onClose;
  final StepPanelTab initialTab;

  /// A value of the response tree was tapped: its full path and where.
  final void Function(String path, Offset globalPosition)? onFieldTap;

  @override
  ConsumerState<StepPanel> createState() => _StepPanelState();
}

class _StepPanelState extends ConsumerState<StepPanel> {
  late StepPanelTab _tab = widget.initialTab;

  @override
  void didUpdateWidget(StepPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index || oldWidget.initialTab != widget.initialTab || oldWidget.flow.id != widget.flow.id) {
      _tab = widget.initialTab;
    }
  }

  Future<void> _update(FlowStep step) => ref.read(flowsProvider.notifier).updateStep(widget.flow.id, widget.index, step);

  Future<void> _changeRequest(FlowStep step) async {
    final picked = await showAddStepPicker(context, ref);
    if (picked == null) return;
    await _update(step.copyWith(endpointId: picked.id));
    ref.read(flowRunProvider(widget.flow.id).notifier).clearFrom(widget.index);
  }

  Future<void> _delete() async {
    await ref.read(flowsProvider.notifier).removeStep(widget.flow.id, widget.index);
    ref.read(flowRunProvider(widget.flow.id).notifier).clearFrom(widget.index);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final flow = widget.flow;
    final index = widget.index;
    if (index >= flow.steps.length) return const SizedBox.shrink();
    final step = flow.steps[index];
    final endpoint = widget.endpoints[step.endpointId];
    final run = ref.watch(flowRunProvider(flow.id));
    final result = index < run.results.length ? run.results[index] : null;
    final response = ref.watch(stepResponseProvider((flowId: flow.id, index: index, endpointId: step.endpointId))).value;
    final tab = _tab == StepPanelTab.run && result == null ? StepPanelTab.step : _tab;

    return Material(
      key: const Key('step-panel'),
      color: AppColors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (endpoint != null) ...[MethodBadge(method: endpoint.method), const SizedBox(width: AppSpacing.sm)],
                Expanded(
                  child: Text(
                    endpoint?.name ?? context.l10n.runMissingEndpoint,
                    style: AppTypography.headlineSm,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  key: const Key('step-panel-close'),
                  tooltip: context.l10n.panelClose,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                _TabChip(tab: StepPanelTab.step, label: context.l10n.panelStep, selected: tab, onTap: _select),
                _TabChip(tab: StepPanelTab.response, label: context.l10n.panelResponse, selected: tab, onTap: _select),
                if (result != null)
                  _TabChip(tab: StepPanelTab.run, label: context.l10n.panelRun, selected: tab, onTap: _select),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: switch (tab) {
                StepPanelTab.step => _stepTab(context, step, endpoint, response),
                StepPanelTab.response => _responseTab(context, response),
                StepPanelTab.run => _runTab(context, endpoint, result!),
              },
            ),
          ],
        ),
      ),
    );
  }

  void _select(StepPanelTab tab) => setState(() => _tab = tab);

  /// A run of this flow is in progress: the step cannot be swapped or removed.
  bool get _locked => ref.watch(flowRunProvider(widget.flow.id).select((s) => s.running));

  Widget _stepTab(BuildContext context, FlowStep step, Endpoint? endpoint, StepResponse? response) {
    final flow = widget.flow;
    final index = widget.index;
    final environment = ref.watch(environmentsProvider).value?.active?.resolvedVariables ?? const <String, String>{};
    final inputs = endpoint == null ? const StepInputs(variables: [], generated: []) : stepInputs(endpoint);

    return ListView(
      children: [
        if (endpoint != null)
          Text(endpoint.url, style: AppTypography.codeSm.copyWith(color: AppColors.onSurfaceVariant)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('step-panel-change-request'),
            onPressed: _locked ? null : () => _changeRequest(step),
            icon: const Icon(Icons.swap_horiz, size: 16),
            label: Text(context.l10n.stepChangeRequest),
          ),
        ),
        const Divider(height: AppSpacing.lg),
        Text(context.l10n.panelInputs, style: Theme.of(context).textTheme.labelMedium),
        for (final name in inputs.variables)
          Builder(builder: (context) {
            final origin = resolveInputOrigin(flow, index, name, environment);
            return _InputRow(
              key: ValueKey('panel-input-$name'),
              name: name,
              origin: originLabel(context, origin, flow, widget.endpoints),
              color: originColor(origin),
            );
          }),
        for (final name in inputs.generated)
          _InputRow(
            key: ValueKey('panel-input-\$$name'),
            name: '\$$name',
            origin: context.l10n.canvasOriginGenerated,
            color: AppColors.onSurfaceVariant,
          ),
        const Divider(height: AppSpacing.lg),
        ExtractsEditor(
          stepIndex: index,
          extract: step.extract,
          knownPaths: _knownPaths(response),
          onChanged: (extract) => _update(step.copyWith(extract: extract)),
        ),
        const Divider(height: AppSpacing.lg),
        AssertionsEditor(
          stepIndex: index,
          assertions: step.assertions,
          onChanged: (assertions) => _update(step.copyWith(assertions: assertions)),
        ),
        SwitchListTile(
          key: ValueKey('stop-on-failure-$index'),
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.stepStopOnFailure),
          value: step.stopOnFailure,
          onChanged: (value) => _update(step.copyWith(stopOnFailure: value)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('step-panel-delete'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: _locked ? null : _delete,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text(context.l10n.canvasDeleteStep),
          ),
        ),
      ],
    );
  }

  /// The paths the step's last response has, or null when there is none (so
  /// nothing is flagged before the step was ever sent).
  Set<String>? _knownPaths(StepResponse? response) {
    if (response == null) return null;
    return {
      'response.status',
      for (final name in response.headers.keys) 'response.headers.$name',
      if (response.isJson) ...responseFields(response.body, limit: 1000).fields.map((f) => f.path),
    };
  }

  Widget _responseTab(BuildContext context, StepResponse? response) {
    if (response == null) return Center(child: Text(context.l10n.canvasNotSent));
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (response.truncated)
            Text(context.l10n.canvasTruncated, style: AppTypography.bodySm.copyWith(color: AppColors.warning)),
          ResponseTree(
            status: response.status,
            headers: response.headers,
            body: response.body,
            onValueTap: widget.onFieldTap,
          ),
        ],
      ),
    );
  }

  Widget _runTab(BuildContext context, Endpoint? endpoint, FlowStepResult result) {
    if (result.status == FlowStepStatus.skipped) return Center(child: Text(context.l10n.runSkippedStep));
    final notifier = ref.read(flowRunProvider(widget.flow.id).notifier);
    final checks = result.assertionResults;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (checks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              context.l10n.assertionsSummary(checks.where((c) => c.passed).length, checks.length),
              key: ValueKey('run-step-assertions-${widget.index}'),
              style: AppTypography.codeSm.copyWith(
                color: checks.every((c) => c.passed) ? AppColors.tertiary : AppColors.error,
              ),
            ),
          ),
        Expanded(
          child: RunStepInspector(
            index: widget.index,
            endpoint: endpoint,
            result: result,
            requestUrl: notifier.requestUrlFor(widget.index, endpoint),
            onRerunFromHere: () =>
                runAndShow(ref, widget.flow.id, (run) => run.rerunFrom(widget.flow, widget.endpoints, widget.index)),
          ),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.tab, required this.label, required this.selected, required this.onTap});

  final StepPanelTab tab;
  final String label;
  final StepPanelTab selected;
  final ValueChanged<StepPanelTab> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = tab == selected;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: InkWell(
        key: ValueKey('step-panel-tab-${tab.name}'),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: () => onTap(tab),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceContainerHigh : null,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Text(
            label,
            style: AppTypography.bodyMd.copyWith(
              color: isSelected ? AppColors.onSurface : AppColors.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({super.key, required this.name, required this.origin, required this.color});

  final String name;
  final String origin;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(name, style: AppTypography.codeSm.copyWith(color: AppColors.primary))),
            Text(origin, style: AppTypography.bodySm.copyWith(color: color)),
          ],
        ),
      );
}
