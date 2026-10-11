import '../engine/flows/flow_step_result.dart';
import '../engine/models/models.dart';

enum StepOutcome { passed, failed, skipped }

/// Why a step failed, taken from the shape of its result rather than from the
/// wording of a message.
enum FailureKind { assertion, network, configuration }

/// One assertion of a step, as the reports show it.
class AssertionReport {
  const AssertionReport({required this.check, required this.passed, this.actual, this.message});

  /// The check in words, like `response.status == "201"`.
  final String check;
  final bool passed;
  final String? actual;
  final String? message;
}

class StepReport {
  const StepReport({
    required this.index,
    required this.endpointName,
    required this.method,
    required this.outcome,
    this.failureKind,
    this.httpStatus,
    required this.elapsedMs,
    this.requestUrl,
    this.failures = const [],
    this.assertions = const [],
  });

  /// 1-based position in the flow.
  final int index;
  final String endpointName;
  final String method;
  final StepOutcome outcome;
  final FailureKind? failureKind;
  final int? httpStatus;
  final int elapsedMs;

  /// The URL actually sent; null when the step did not send anything.
  final String? requestUrl;

  /// What went wrong, one entry per failed assertion (or the single error).
  final List<String> failures;
  final List<AssertionReport> assertions;
}

class FlowReport {
  const FlowReport({required this.id, required this.name, required this.steps, required this.duration});

  final String id;
  final String name;
  final List<StepReport> steps;
  final Duration duration;

  /// A flow passes unless a step failed; skipped steps only follow a failure.
  bool get passed => steps.every((s) => s.outcome != StepOutcome.failed);
}

class RunReport {
  const RunReport({
    required this.workspace,
    required this.environment,
    required this.startedAt,
    required this.duration,
    required this.flows,
  });

  final String workspace;
  final String? environment;
  final DateTime startedAt;
  final Duration duration;
  final List<FlowReport> flows;

  Iterable<StepReport> get _steps => flows.expand((f) => f.steps);

  int get flowsPassed => flows.where((f) => f.passed).length;
  int get flowsFailed => flows.length - flowsPassed;
  int get steps => _steps.length;
  int get stepsPassed => _steps.where((s) => s.outcome == StepOutcome.passed).length;
  int get stepsFailed => _steps.where((s) => s.outcome == StepOutcome.failed).length;
  int get stepsSkipped => _steps.where((s) => s.outcome == StepOutcome.skipped).length;
  bool get passed => flowsFailed == 0;
}

/// The report of one step. [endpoint] is null when the flow points at one that
/// is not in the workspace.
StepReport stepReportFrom({
  required int index,
  required FlowStep step,
  required Endpoint? endpoint,
  required FlowStepResult result,
}) {
  final response = result.response;
  final assertions = [
    for (final r in result.assertionResults)
      AssertionReport(check: r.assertion.describe(), passed: r.passed, actual: r.actual, message: r.message),
  ];

  final StepOutcome outcome;
  FailureKind? kind;
  var failures = const <String>[];
  switch (result.status) {
    case FlowStepStatus.success:
      outcome = StepOutcome.passed;
    case FlowStepStatus.skipped:
      outcome = StepOutcome.skipped;
    case FlowStepStatus.failure:
      outcome = StepOutcome.failed;
      final failedAssertions = [
        for (final r in result.assertionResults)
          if (!r.passed && r.message != null) r.message!,
      ];
      if (failedAssertions.isNotEmpty) {
        kind = FailureKind.assertion;
        failures = failedAssertions;
      } else {
        kind = response?.error != null ? FailureKind.network : FailureKind.configuration;
        failures = [result.failureReason ?? response?.error ?? 'The step failed'];
      }
  }

  return StepReport(
    index: index,
    endpointName: endpoint?.name ?? 'Missing endpoint (${step.endpointId})',
    method: endpoint?.method ?? '',
    outcome: outcome,
    failureKind: kind,
    httpStatus: response?.status,
    elapsedMs: response?.elapsedMs ?? 0,
    requestUrl: response?.requestUrl,
    failures: failures,
    assertions: assertions,
  );
}
