import '../redactor.dart';
import '../run_report.dart';

/// A JUnit XML report: a `testsuite` per flow, a `testcase` per step. A failed
/// assertion is a `failure`; a network or configuration problem is an `error`,
/// as test tools expect.
String junitReport(RunReport run, Redactor redactor) {
  String clean(String text) => _withoutControlChars(redactor.redact(text));
  String attr(String text) => _escape(clean(text), attribute: true);
  String body(String text) => _escape(clean(text), attribute: false);

  final out = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n');
  out.writeln(
    '<testsuites name="${attr(run.workspace)}" tests="${run.steps}" failures="${_failures(run.flows.expand((f) => f.steps))}" '
    'errors="${_errors(run.flows.expand((f) => f.steps))}" skipped="${run.stepsSkipped}" time="${_seconds(run.duration.inMilliseconds)}">',
  );

  for (final flow in run.flows) {
    out.writeln(
      '  <testsuite name="${attr(flow.name)}" tests="${flow.steps.length}" failures="${_failures(flow.steps)}" '
      'errors="${_errors(flow.steps)}" skipped="${flow.steps.where((s) => s.outcome == StepOutcome.skipped).length}" '
      'time="${_seconds(flow.duration.inMilliseconds)}">',
    );
    for (final step in flow.steps) {
      final head =
          '<testcase classname="${attr(flow.name)}" name="${attr('${step.index}. ${step.endpointName}')}" time="${_seconds(step.elapsedMs)}"';
      switch (step.outcome) {
        case StepOutcome.passed:
          out.writeln('    $head/>');
        case StepOutcome.skipped:
          out.writeln('    $head>\n      <skipped/>\n    </testcase>');
        case StepOutcome.failed:
          final isFailure = step.failureKind == FailureKind.assertion;
          final tag = isFailure ? 'failure' : 'error';
          final type = switch (step.failureKind) {
            FailureKind.assertion => 'AssertionFailure',
            FailureKind.network => 'NetworkError',
            _ => 'ConfigurationError',
          };
          final first = step.failures.isEmpty ? 'The step failed' : step.failures.first;
          out.writeln(
            '    $head>\n      <$tag message="${attr(first)}" type="$type">${body(step.failures.join('\n'))}</$tag>\n    </testcase>',
          );
      }
    }
    out.writeln('  </testsuite>');
  }
  out.writeln('</testsuites>');
  return out.toString();
}

int _failures(Iterable<StepReport> steps) =>
    steps.where((s) => s.outcome == StepOutcome.failed && s.failureKind == FailureKind.assertion).length;

int _errors(Iterable<StepReport> steps) =>
    steps.where((s) => s.outcome == StepOutcome.failed && s.failureKind != FailureKind.assertion).length;

String _seconds(int ms) => (ms / 1000).toStringAsFixed(3);

/// XML 1.0 cannot carry most control characters, not even escaped.
String _withoutControlChars(String text) => text.replaceAll(RegExp('[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '');

String _escape(String text, {required bool attribute}) {
  final escaped = text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
  return attribute ? escaped.replaceAll('"', '&quot;').replaceAll("'", '&apos;') : escaped;
}
