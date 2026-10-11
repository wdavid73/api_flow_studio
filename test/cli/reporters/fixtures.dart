import 'package:api_flow_studio/cli/run_report.dart';

StepReport passedStep(int index, String name, {int status = 200, int ms = 120, String? url}) => StepReport(
      index: index,
      endpointName: name,
      method: 'GET',
      outcome: StepOutcome.passed,
      httpStatus: status,
      elapsedMs: ms,
      requestUrl: url,
      assertions: const [AssertionReport(check: 'response.status == "200"', passed: true)],
    );

StepReport failedStep(int index, String name, {List<String>? failures, FailureKind kind = FailureKind.assertion}) => StepReport(
      index: index,
      endpointName: name,
      method: 'POST',
      outcome: StepOutcome.failed,
      failureKind: kind,
      httpStatus: kind == FailureKind.assertion ? 404 : null,
      elapsedMs: 45,
      failures: failures ?? ['Assertion failed: expected response.status == "201", got "404"'],
      assertions: kind == FailureKind.assertion
          ? const [
              AssertionReport(
                check: 'response.status == "201"',
                passed: false,
                actual: '404',
                message: 'Assertion failed: expected response.status == "201", got "404"',
              ),
            ]
          : const [],
    );

StepReport skippedStep(int index, String name) => StepReport(
      index: index,
      endpointName: name,
      method: 'GET',
      outcome: StepOutcome.skipped,
      elapsedMs: 0,
    );

RunReport sampleRun() => RunReport(
      workspace: 'commodo',
      environment: 'qa',
      startedAt: DateTime.utc(2026, 10, 11, 14, 3, 22),
      duration: const Duration(milliseconds: 1400),
      flows: [
        FlowReport(
          id: 'f-signup',
          name: 'Signup',
          duration: const Duration(milliseconds: 900),
          steps: [passedStep(1, 'Log in'), failedStep(2, 'Create item'), skippedStep(3, 'List items')],
        ),
        FlowReport(
          id: 'f-smoke',
          name: 'Smoke',
          duration: const Duration(milliseconds: 500),
          steps: [passedStep(1, 'Health', ms: 30)],
        ),
      ],
    );
