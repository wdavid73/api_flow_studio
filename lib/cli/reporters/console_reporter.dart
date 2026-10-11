import '../redactor.dart';
import '../run_report.dart';

/// The plain-text lines the runner prints. Every function masks sensitive
/// values with [Redactor] before returning, so nothing it writes can leak one.

String formatFlowHeader(String name, int steps, Redactor redactor) =>
    redactor.redact('Flow: $name ($steps ${steps == 1 ? 'step' : 'steps'})');

/// One step: its mark, number and endpoint, the HTTP status and time, then one
/// line per failure (and the request, with [verbose]).
String formatStep(StepReport step, Redactor redactor, {bool verbose = false}) {
  final mark = switch (step.outcome) {
    StepOutcome.passed => 'PASS',
    StepOutcome.failed => 'FAIL',
    StepOutcome.skipped => 'SKIP',
  };
  final label = '${step.index}. ${step.endpointName}';
  final lines = <String>[];

  if (step.outcome == StepOutcome.skipped) {
    lines.add('  [$mark] $label');
  } else {
    // A long name is not cut: it just pushes the columns to the right.
    final name = label.length >= _nameWidth ? '$label ' : label.padRight(_nameWidth);
    final status = (step.httpStatus?.toString() ?? '-').padLeft(3);
    lines.add('  [$mark] $name$status   ${'${step.elapsedMs} ms'.padLeft(6)}');
  }
  if (verbose && step.requestUrl != null) lines.add('$_indent${step.method} ${step.requestUrl}');
  for (final failure in step.failures) {
    lines.add('$_indent$failure');
  }
  return redactor.redact(lines.join('\n'));
}

String formatSummary(RunReport run, Redactor redactor) {
  String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  final seconds = (run.duration.inMilliseconds / 1000).toStringAsFixed(1);
  return redactor.redact(
    '${count(run.flows.length, 'flow', 'flows')}: ${run.flowsPassed} passed, ${run.flowsFailed} failed - '
    '${count(run.steps, 'step', 'steps')}: ${run.stepsPassed} passed, ${run.stepsFailed} failed, ${run.stepsSkipped} skipped - '
    '$seconds s',
  );
}

const int _nameWidth = 24;

/// Lines under a step start here, under the endpoint name.
const String _indent = '         ';
