import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/flows/flow_runner.dart';
import '../../engine/flows/flow_step_result.dart';
import '../../engine/models/models.dart';
import '../../engine/variables/interpolator.dart';
import '../environments/environments_provider.dart';
import '../projects/projects_provider.dart';
import '../session/session_provider.dart' show sessionExecutorProvider;

/// What the canvas knows about the last runs of one flow, in memory only:
/// nothing here is written to disk or to the history.
class FlowRunState {
  const FlowRunState({
    this.results = const [],
    this.resultAt = const [],
    this.initialVariables = const {},
    this.running = false,
    this.runningFrom,
    this.runningTo,
    this.focusIndex,
  });

  /// One entry per step (null: no result in this session).
  final List<FlowStepResult?> results;

  /// When each entry of [results] arrived.
  final List<DateTime?> resultAt;

  /// The environment variables the last run started from.
  final Map<String, String> initialVariables;

  final bool running;

  /// The steps the run in progress covers, inclusive (null when idle).
  final int? runningFrom;
  final int? runningTo;

  /// Whether step [index] is part of the run in progress and has no result yet.
  bool isPending(int index) =>
      running &&
      runningFrom != null &&
      index >= runningFrom! &&
      index <= runningTo! &&
      (index >= results.length || results[index] == null);

  /// The step to show after a run: the first that failed, else the last that ran.
  final int? focusIndex;

  FlowRunState copyWith({
    List<FlowStepResult?>? results,
    List<DateTime?>? resultAt,
    Map<String, String>? initialVariables,
    bool? running,
    (int, int)? Function()? runningRange,
    int? Function()? focusIndex,
  }) {
    final range = runningRange == null ? (runningFrom, runningTo) : runningRange();
    return FlowRunState(
      results: results ?? this.results,
      resultAt: resultAt ?? this.resultAt,
      initialVariables: initialVariables ?? this.initialVariables,
      running: running ?? this.running,
      runningFrom: range?.$1,
      runningTo: range?.$2,
      focusIndex: focusIndex == null ? this.focusIndex : focusIndex(),
    );
  }
}

/// The first step at or before [upTo] without a successful result -- a step
/// with no result, a failed one or a skipped one still has to run -- or
/// [upTo] itself when every earlier step succeeded.
int firstPendingStep(List<FlowStepResult?> results, int upTo) {
  for (var i = 0; i < upTo; i++) {
    final result = i < results.length ? results[i] : null;
    if (result?.status != FlowStepStatus.success) return i;
  }
  return upTo;
}

/// Runs one flow from the canvas -- all of it, up to a step, or again from a
/// step -- and keeps the results while the app is open. Each run goes through
/// the session executor, like a send from the request builder, but never
/// writes the history. A change of project drops everything, and a run still
/// in flight when it happens leaves no trace in the new project.
class FlowRunNotifier extends FamilyNotifier<FlowRunState, String> {
  /// Bumped whenever this state is thrown away (a change of project
  /// invalidates it), so callbacks of a run started before are dropped. `ref`
  /// cannot be read from those callbacks once the project changed, hence a
  /// counter instead of comparing project ids.
  int _generation = 0;

  @override
  FlowRunState build(String flowId) {
    ref.watch(activeProjectIdProvider);
    ref.onDispose(() => _generation++);
    _generation++;
    return const FlowRunState();
  }

  /// Runs every step. Returns the step to show afterwards ([FlowRunState.focusIndex]).
  Future<int?> runAll(Flow flow, Map<String, Endpoint> endpoints) async {
    final variables = await _environmentVariables();
    final count = flow.steps.length;
    state = FlowRunState(
      results: List<FlowStepResult?>.filled(count, null),
      resultAt: List<DateTime?>.filled(count, null),
      initialVariables: variables,
    );
    return _run(flow, endpoints, startIndex: 0);
  }

  /// Runs what [index] needs: from the first step before it that has not
  /// succeeded, up to [index]. Results after [index] are dropped, since they
  /// were computed from values this run may change.
  Future<int?> runUntil(Flow flow, Map<String, Endpoint> endpoints, int index) async {
    final variables = await _environmentVariables();
    final results = _sized(state.results, flow.steps.length);
    final start = firstPendingStep(results, index);
    state = state.copyWith(
      results: [for (var i = 0; i < results.length; i++) i < start ? results[i] : null],
      resultAt: _clearedTimes(flow.steps.length, start),
      initialVariables: variables,
    );
    return _run(flow, endpoints, startIndex: start, endIndex: index);
  }

  /// Runs again from [index] to the end, keeping what came before.
  Future<int?> rerunFrom(Flow flow, Map<String, Endpoint> endpoints, int index) async {
    final variables = await _environmentVariables();
    final results = _sized(state.results, flow.steps.length);
    state = state.copyWith(
      results: [for (var i = 0; i < results.length; i++) i < index ? results[i] : null],
      resultAt: _clearedTimes(flow.steps.length, index),
      initialVariables: variables,
    );
    return _run(flow, endpoints, startIndex: index);
  }

  /// Drops the results of the steps from [index] on (after the flow changed there).
  void clearFrom(int index) {
    state = state.copyWith(
      results: [for (var i = 0; i < state.results.length; i++) i < index ? state.results[i] : null],
      resultAt: [for (var i = 0; i < state.resultAt.length; i++) i < index ? state.resultAt[i] : null],
      focusIndex: () => null,
    );
  }

  /// The variable pool as it stood right before [index] ran: the run's
  /// environment variables plus every earlier step's extracted ones -- the
  /// same way [FlowRunner] accumulates them.
  Map<String, String> variablesEnteringStep(int index) {
    final variables = {...state.initialVariables};
    for (var i = 0; i < index && i < state.results.length; i++) {
      final result = state.results[i];
      if (result != null) variables.addAll(result.extractedVariables);
    }
    return variables;
  }

  /// The url step [index] was sent to: the one the executor reports (with any
  /// generated `{{$token}}` values), else [endpoint]'s url resolved with the
  /// pool entering the step. Null when the step has no result or was skipped.
  String? requestUrlFor(int index, Endpoint? endpoint) {
    final result = index < state.results.length ? state.results[index] : null;
    if (result == null || result.status == FlowStepStatus.skipped || endpoint == null) return null;
    return result.response?.requestUrl ?? interpolate(endpoint.url, variablesEnteringStep(index));
  }

  Future<int?> _run(Flow flow, Map<String, Endpoint> endpoints, {required int startIndex, int? endIndex}) async {
    final generation = _generation;
    bool stale() => generation != _generation;

    state = state.copyWith(
      running: true,
      runningRange: () => (startIndex, endIndex ?? flow.steps.length - 1),
      focusIndex: () => null,
    );
    final runner = FlowRunner(executor: ref.read(sessionExecutorProvider));
    try {
      await runner.runFrom(
        flow,
        startIndex: startIndex,
        endIndex: endIndex,
        endpoints: endpoints,
        seedVariables: variablesEnteringStep(startIndex),
        onStepResult: (index, result) {
          if (stale()) return;
          state = state.copyWith(
            results: [...state.results]..[index] = result,
            resultAt: [...state.resultAt]..[index] = DateTime.now(),
          );
        },
      );
    } finally {
      if (!stale()) {
        state = state.copyWith(running: false, runningRange: () => null, focusIndex: () => _focus(state.results));
      }
    }
    return stale() ? null : state.focusIndex;
  }

  Future<Map<String, String>> _environmentVariables() async {
    // Awaits the provider's own future: a run can start before the
    // environments finish loading from disk.
    final environments = await ref.read(environmentsProvider.future);
    return environments.active?.resolvedVariables ?? const {};
  }

  List<FlowStepResult?> _sized(List<FlowStepResult?> results, int count) =>
      [for (var i = 0; i < count; i++) i < results.length ? results[i] : null];

  List<DateTime?> _clearedTimes(int count, int from) =>
      [for (var i = 0; i < count; i++) i < from && i < state.resultAt.length ? state.resultAt[i] : null];

  int? _focus(List<FlowStepResult?> results) {
    int? candidate;
    for (var i = 0; i < results.length; i++) {
      final status = results[i]?.status;
      if (status == FlowStepStatus.failure) return i;
      if (status == FlowStepStatus.success) candidate = i;
    }
    return candidate;
  }
}

final flowRunProvider = NotifierProvider.family<FlowRunNotifier, FlowRunState, String>(FlowRunNotifier.new);
