import 'dart:convert';

import '../redactor.dart';
import '../run_report.dart';

/// The run as JSON, for tools that want more than JUnit gives. Strings are masked
/// *before* encoding: JSON would escape a quote or a line break inside a secret
/// and the masked text would no longer match.
String jsonReport(RunReport run, Redactor redactor) {
  final tree = {
    'workspace': run.workspace,
    'environment': run.environment,
    'startedAt': run.startedAt.toUtc().toIso8601String(),
    'durationMs': run.duration.inMilliseconds,
    'summary': {
      'flows': run.flows.length,
      'flowsFailed': run.flowsFailed,
      'steps': run.steps,
      'stepsFailed': run.stepsFailed,
      'stepsSkipped': run.stepsSkipped,
    },
    'flows': [for (final flow in run.flows) _flow(flow)],
  };
  return '${const JsonEncoder.withIndent('  ').convert(_mask(tree, redactor))}\n';
}

Map<String, Object?> _flow(FlowReport flow) => {
      'id': flow.id,
      'name': flow.name,
      'status': flow.passed ? 'passed' : 'failed',
      'durationMs': flow.duration.inMilliseconds,
      'steps': [for (final step in flow.steps) _step(step)],
    };

Map<String, Object?> _step(StepReport step) => {
      'index': step.index,
      'endpoint': step.endpointName,
      'method': step.method,
      'status': step.outcome.name,
      if (step.httpStatus != null) 'httpStatus': step.httpStatus,
      'elapsedMs': step.elapsedMs,
      if (step.failureKind != null) 'failureKind': step.failureKind!.name,
      if (step.failures.isNotEmpty) 'failures': step.failures,
      'assertions': [
        for (final a in step.assertions)
          {
            'check': a.check,
            'passed': a.passed,
            if (!a.passed && a.actual != null) 'actual': a.actual,
            if (!a.passed && a.message != null) 'message': a.message,
          },
      ],
    };

Object? _mask(Object? value, Redactor redactor) => switch (value) {
      String() => redactor.redact(value),
      List() => [for (final item in value) _mask(item, redactor)],
      Map() => {for (final entry in value.entries) entry.key: _mask(entry.value, redactor)},
      _ => value,
    };
