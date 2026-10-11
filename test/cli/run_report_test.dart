import 'package:api_flow_studio/cli/run_report.dart';
import 'package:api_flow_studio/engine/flows/flow_step_result.dart';
import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const endpoint = Endpoint(id: 'e-1', groupId: 'g', name: 'Create item', method: 'POST', url: '/items');
  const step = FlowStep(endpointId: 'e-1');

  StepReport report(FlowStepResult result, {Endpoint? ep = endpoint}) =>
      stepReportFrom(index: 2, step: step, endpoint: ep, result: result);

  group('a passing step', () {
    test('carries the response data and every assertion as passed', () {
      final r = report(FlowStepResult(
        status: FlowStepStatus.success,
        response: const ExecutedResponse(status: 201, elapsedMs: 45, requestUrl: 'https://x/items'),
        assertionResults: [
          AssertionResult(assertion: const Assertion(field: 'response.status', expected: '201'), passed: true, actual: '201'),
        ],
      ));

      expect(r.index, 2);
      expect(r.endpointName, 'Create item');
      expect(r.method, 'POST');
      expect(r.outcome, StepOutcome.passed);
      expect(r.failureKind, isNull);
      expect(r.httpStatus, 201);
      expect(r.elapsedMs, 45);
      expect(r.requestUrl, 'https://x/items');
      expect(r.failures, isEmpty);
      expect(r.assertions.single.check, 'response.status == "201"');
      expect(r.assertions.single.passed, isTrue);
    });
  });

  group('failures are classified by structure, not by message text', () {
    test('a failed assertion is an assertion failure and lists each failed message', () {
      final r = report(FlowStepResult(
        status: FlowStepStatus.failure,
        response: const ExecutedResponse(status: 404),
        failureReason: 'Assertion failed: a\nAssertion failed: b',
        assertionResults: [
          AssertionResult(
            assertion: const Assertion(field: 'response.status', expected: '201'),
            passed: false,
            actual: '404',
            message: 'Assertion failed: expected response.status == "201", got "404"',
          ),
          AssertionResult(assertion: const Assertion(field: 'response.body.id', operator: AssertionOperator.exists), passed: true),
        ],
      ));

      expect(r.outcome, StepOutcome.failed);
      expect(r.failureKind, FailureKind.assertion);
      expect(r.failures, ['Assertion failed: expected response.status == "201", got "404"']);
      expect(r.assertions.map((a) => a.passed), [false, true]);
      expect(r.assertions.first.actual, '404');
    });

    test('a transport error is a network failure with its text', () {
      final r = report(FlowStepResult(
        status: FlowStepStatus.failure,
        response: const ExecutedResponse(error: 'Connection refused'),
        failureReason: 'Connection refused',
      ));

      expect(r.failureKind, FailureKind.network);
      expect(r.failures, ['Connection refused']);
      expect(r.httpStatus, isNull);
    });

    test('a transport error on a url that still has {{variables}} says which are unresolved', () {
      final r = report(FlowStepResult(
        status: FlowStepStatus.failure,
        response: const ExecutedResponse(
          error: 'DioException [unknown]: null\nError: Invalid argument(s): No host specified in URI',
          requestUrl: '{{base}}/items/{{id}}?x={{\$uuid}}&again={{base}}',
        ),
        failureReason: 'DioException [unknown]: null',
      ));

      expect(r.failureKind, FailureKind.network);
      expect(r.failures, hasLength(1));
      expect(r.failures.single, startsWith('Unresolved variables in the URL: {{base}}, {{id}}, {{\$uuid}}'));
      expect(r.failures.single, contains('--var'));
      expect(r.failures.single, isNot(contains('DioException')));
    });

    test('a single unresolved variable is named in the singular', () {
      final r = report(FlowStepResult(
        status: FlowStepStatus.failure,
        response: const ExecutedResponse(error: 'boom', requestUrl: '{{nope}}/x'),
        failureReason: 'boom',
      ));

      expect(r.failures.single, startsWith('Unresolved variable in the URL: {{nope}}'));
    });

    test('a transport error on a fully resolved url keeps its own text', () {
      final r = report(FlowStepResult(
        status: FlowStepStatus.failure,
        response: const ExecutedResponse(error: 'Connection refused', requestUrl: 'https://x/items'),
        failureReason: 'Connection refused',
      ));

      expect(r.failures, ['Connection refused']);
    });

    test('a missing endpoint is a configuration failure, named by its id', () {
      final r = report(
        const FlowStepResult(status: FlowStepStatus.failure, failureReason: 'Endpoint "e-9" not found'),
        ep: null,
      );

      expect(r.failureKind, FailureKind.configuration);
      expect(r.failures, ['Endpoint "e-9" not found']);
      expect(r.endpointName, 'Missing endpoint (e-1)');
      expect(r.method, '');
    });

    test('a reason that merely starts with "Assertion failed" is not an assertion failure without results', () {
      final r = report(const FlowStepResult(status: FlowStepStatus.failure, failureReason: 'Assertion failed: odd'));

      expect(r.failureKind, FailureKind.configuration);
    });
  });

  test('a skipped step has no data', () {
    final r = report(const FlowStepResult(status: FlowStepStatus.skipped));

    expect(r.outcome, StepOutcome.skipped);
    expect(r.failureKind, isNull);
    expect(r.elapsedMs, 0);
    expect(r.assertions, isEmpty);
  });

  group('FlowReport and RunReport', () {
    StepReport s(StepOutcome o) => StepReport(
          index: 1,
          endpointName: 'x',
          method: 'GET',
          outcome: o,
          elapsedMs: 10,
        );

    test('a flow fails when any step failed, otherwise passes (skipped alone is not a failure)', () {
      expect(FlowReport(id: 'f', name: 'F', steps: [s(StepOutcome.passed), s(StepOutcome.failed)], duration: Duration.zero).passed, isFalse);
      expect(FlowReport(id: 'f', name: 'F', steps: [s(StepOutcome.passed), s(StepOutcome.skipped)], duration: Duration.zero).passed, isTrue);
      expect(const FlowReport(id: 'f', name: 'F', steps: [], duration: Duration.zero).passed, isTrue);
    });

    test('the run totals count flows and steps', () {
      final run = RunReport(
        workspace: 'ws',
        environment: 'qa',
        startedAt: DateTime.utc(2026),
        duration: const Duration(seconds: 2),
        flows: [
          FlowReport(id: 'a', name: 'A', steps: [s(StepOutcome.passed), s(StepOutcome.failed), s(StepOutcome.skipped)], duration: Duration.zero),
          FlowReport(id: 'b', name: 'B', steps: [s(StepOutcome.passed)], duration: Duration.zero),
        ],
      );

      expect(run.flowsPassed, 1);
      expect(run.flowsFailed, 1);
      expect(run.stepsPassed, 2);
      expect(run.stepsFailed, 1);
      expect(run.stepsSkipped, 1);
      expect(run.steps, 4);
      expect(run.passed, isFalse);
    });
  });
}
