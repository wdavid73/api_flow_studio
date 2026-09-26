import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/flows/flow_runner.dart';
import '../../engine/flows/flow_step_result.dart';
import '../../engine/models/models.dart';
import '../environments/environments_provider.dart';
import '../request_builder/send_provider.dart' show requestExecutorProvider;
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'run_step_card.dart';

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
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _results = List<FlowStepResult?>.filled(widget.flow.steps.length, null);
    });

    final executor = ref.read(requestExecutorProvider);
    final runner = FlowRunner(executor: executor);
    // Awaits the environments provider's own future rather than reading its
    // (possibly still-loading) `.value` snapshot -- this runs from
    // initState, immediately on mount, which can race the async on-disk
    // read that resolves it.
    final environments = await ref.read(environmentsProvider.future);
    final variables = environments.active?.resolvedVariables ?? const {};

    await runner.run(
      widget.flow,
      endpoints: widget.endpoints,
      initialVariables: variables,
      onStepResult: (index, result) {
        if (!mounted) return;
        setState(() => _results[index] = result);
      },
    );

    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    final passed = _results.where((r) => r?.status == FlowStepStatus.success).length;
    final failed = _results.where((r) => r?.status == FlowStepStatus.failure).length;
    final skipped = _results.where((r) => r?.status == FlowStepStatus.skipped).length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          key: const Key('run-view-back-button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.flow.name),
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
              child: ListView.builder(
                itemCount: widget.flow.steps.length,
                itemBuilder: (context, index) {
                  final step = widget.flow.steps[index];
                  return RunStepCard(
                    index: index,
                    endpoint: widget.endpoints[step.endpointId],
                    result: index < _results.length ? _results[index] : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
