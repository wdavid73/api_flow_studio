import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../flow_run_provider.dart';
import '../flows_screen.dart' show selectedStepIndexProvider, stepPanelTabProvider;
import 'step_panel.dart';

/// Starts a run of flow [flowId] with [action] and, once it is over, selects
/// the step it points at (the first failure, else the last that ran) and opens
/// the side panel on its Run tab. Everything is read before the run starts:
/// the widget that asked may be gone when it ends, and if another flow was
/// opened meanwhile the selection belongs to that one and is left alone.
Future<void> runAndShow(
  WidgetRef ref,
  String flowId,
  Future<int?> Function(FlowRunNotifier run) action,
) async {
  final run = ref.read(flowRunProvider(flowId).notifier);
  final selection = ref.read(selectedStepIndexProvider.notifier);
  final tab = ref.read(stepPanelTabProvider.notifier);

  final focus = await action(run);
  if (focus == null || !selection.mounted || !tab.mounted) return;
  tab.state = StepPanelTab.run;
  selection.state = focus;
}
