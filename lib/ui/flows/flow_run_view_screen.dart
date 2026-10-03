import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/flows/flow_runner.dart';
import '../../engine/flows/flow_step_result.dart';
import '../../engine/models/models.dart';
import '../../engine/variables/interpolator.dart';
import '../environments/environments_provider.dart';
import '../session/session_provider.dart' show sessionExecutorProvider;
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'run_step_card.dart';
import 'run_step_inspector.dart';

/// Runs a [Flow] end-to-end against the currently active environment and
/// shows each step's live result as it completes -- pushed from
/// [FlowsScreen] when the user taps "Run Flow".
class FlowRunViewScreen extends ConsumerStatefulWidget {
  const FlowRunViewScreen({super.key, required this.flow, required this.endpoints});

  final Flow flow;
  final Map<String, Endpoint> endpoints;

  @override
  ConsumerState<FlowRunViewScreen> createState() => _FlowRunViewScreenState();
}

class _FlowRunViewScreenState extends ConsumerState<FlowRunViewScreen> {
  List<FlowStepResult?> _results = const [];
  Map<String, String> _initialVariables = const {};
  int? _selectedIndex;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  /// The variable pool as it stood right before [index] executed: the
  /// run's initial (environment) variables plus every earlier step's
  /// extracted variables -- reconstructed the same way [FlowRunner]
  /// accumulates them internally, so a step can be re-run in isolation
  /// with the exact pool it originally saw.
  Map<String, String> _variablesEnteringStep(int index) {
    final variables = {..._initialVariables};
    for (var i = 0; i < index; i++) {
      final result = i < _results.length ? _results[i] : null;
      if (result != null) variables.addAll(result.extractedVariables);
    }
    return variables;
  }

  String? _requestUrlFor(int index) {
    final result = index < _results.length ? _results[index] : null;
    if (result == null || result.status == FlowStepStatus.skipped) return null;
    final endpoint = widget.endpoints[widget.flow.steps[index].endpointId];
    if (endpoint == null) return null;
    return interpolate(endpoint.url, _variablesEnteringStep(index));
  }

  /// Picks which step the inspector shows once a run finishes: the first
  /// failure if there is one (matching design/flow_run_view/screen.png's
  /// "active selection" on the step that halted the pipeline), else the
  /// last step that actually ran, else nothing.
  void _autoSelect() {
    var candidate = -1;
    for (var i = 0; i < _results.length; i++) {
      final status = _results[i]?.status;
      if (status == FlowStepStatus.failure) {
        candidate = i;
        break;
      }
      if (status == FlowStepStatus.success) candidate = i;
    }
    _selectedIndex = candidate >= 0 ? candidate : null;
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _results = List<FlowStepResult?>.filled(widget.flow.steps.length, null);
      _selectedIndex = null;
    });

    final executor = ref.read(sessionExecutorProvider);
    final runner = FlowRunner(executor: executor);
    // Awaits the environments provider's own future rather than reading its
    // (possibly still-loading) `.value` snapshot -- this runs from
    // initState, immediately on mount, which can race the async on-disk
    // read that resolves it.
    final environments = await ref.read(environmentsProvider.future);
    final variables = environments.active?.resolvedVariables ?? const {};
    _initialVariables = variables;

    await runner.run(
      widget.flow,
      endpoints: widget.endpoints,
      initialVariables: variables,
      onStepResult: (index, result) {
        if (!mounted) return;
        setState(() => _results[index] = result);
      },
    );

    if (mounted) setState(_autoSelect);
    if (mounted) setState(() => _running = false);
  }

  Future<void> _rerunFromStep(int startIndex) async {
    final seed = _variablesEnteringStep(startIndex);
    setState(() {
      _running = true;
      for (var i = startIndex; i < _results.length; i++) {
        _results[i] = null;
      }
    });

    final executor = ref.read(sessionExecutorProvider);
    final runner = FlowRunner(executor: executor);

    await runner.runFrom(
      widget.flow,
      startIndex: startIndex,
      endpoints: widget.endpoints,
      seedVariables: seed,
      onStepResult: (index, result) {
        if (!mounted) return;
        setState(() => _results[index] = result);
      },
    );

    if (mounted) setState(_autoSelect);
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final passed = _results.where((r) => r?.status == FlowStepStatus.success).length;
    final failed = _results.where((r) => r?.status == FlowStepStatus.failure).length;
    final skipped = _results.where((r) => r?.status == FlowStepStatus.skipped).length;
    final totalMs = _results.fold<int>(0, (sum, r) => sum + (r?.response?.elapsedMs ?? 0));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          key: const Key('run-view-back-button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.flow.name, style: AppTypography.title),
        actions: [
          IconButton(
            key: const Key('re-run-flow-button'),
            tooltip: 'Re-run Flow',
            icon: const Icon(Icons.replay),
            onPressed: _running ? null : _run,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              key: const Key('run-summary-strip'),
              children: [
                Text('$passed passed', style: const TextStyle(color: AppColors.tertiary)),
                const SizedBox(width: AppSpacing.md),
                Text('$failed failed', style: const TextStyle(color: AppColors.error)),
                const SizedBox(width: AppSpacing.md),
                Text('$skipped skipped', style: const TextStyle(color: AppColors.outline)),
                const SizedBox(width: AppSpacing.md),
                Text(
                  '$totalMs ms',
                  key: const Key('run-summary-total'),
                  style: AppTypography.codeMd.copyWith(color: AppColors.onSurfaceVariant),
                ),
                if (_running) ...[
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
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 420,
                    child: ListView.builder(
                      itemCount: widget.flow.steps.length,
                      itemBuilder: (context, index) {
                        final step = widget.flow.steps[index];
                        return RunStepCard(
                          index: index,
                          endpoint: widget.endpoints[step.endpointId],
                          result: index < _results.length ? _results[index] : null,
                          isSelected: _selectedIndex == index,
                          onSelect: () => setState(() => _selectedIndex = index),
                        );
                      },
                    ),
                  ),
                  const VerticalDivider(width: AppSpacing.md * 2),
                  Expanded(
                    child: _selectedIndex == null || _results[_selectedIndex!] == null
                        ? const Center(
                            key: Key('no-step-selected'),
                            child: Text('Select a step to see its details'),
                          )
                        : RunStepInspector(
                            index: _selectedIndex!,
                            endpoint: widget.endpoints[widget.flow.steps[_selectedIndex!].endpointId],
                            result: _results[_selectedIndex!]!,
                            requestUrl: _requestUrlFor(_selectedIndex!),
                            onRerunFromHere: () => _rerunFromStep(_selectedIndex!),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
