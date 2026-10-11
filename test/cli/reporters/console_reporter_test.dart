import 'package:api_flow_studio/cli/redactor.dart';
import 'package:api_flow_studio/cli/reporters/console_reporter.dart';
import 'package:api_flow_studio/cli/run_report.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  final plain = Redactor();

  test('the flow header counts its steps', () {
    expect(formatFlowHeader('Signup', 3, plain), 'Flow: Signup (3 steps)');
    expect(formatFlowHeader('Smoke', 1, plain), 'Flow: Smoke (1 step)');
  });

  test('a passing step shows its mark, number, name, status and time', () {
    expect(formatStep(passedStep(1, 'Log in'), plain), '  [PASS] 1. Log in               200   120 ms');
  });

  test('a failed step lists each failure under it', () {
    expect(
      formatStep(failedStep(2, 'Create item'), plain),
      '  [FAIL] 2. Create item          404    45 ms\n'
      '         Assertion failed: expected response.status == "201", got "404"',
    );
  });

  test('a step that never got a response shows a dash instead of a status', () {
    final text = formatStep(failedStep(1, 'Ping', kind: FailureKind.network, failures: ['Connection refused']), plain);

    expect(text, startsWith('  [FAIL] 1. Ping                   -    45 ms'));
    expect(text, endsWith('\n         Connection refused'));
  });

  test('a skipped step has no status or time', () {
    expect(formatStep(skippedStep(3, 'List items'), plain), '  [SKIP] 3. List items');
  });

  test('a long name is not cut, it just pushes the columns', () {
    final text = formatStep(passedStep(1, 'A very long endpoint name that goes on'), plain);

    expect(text, contains('A very long endpoint name that goes on 200'));
  });

  test('--verbose adds the method and the url actually sent', () {
    final text = formatStep(passedStep(1, 'Log in', url: 'https://x/login?a=1'), plain, verbose: true);

    expect(text, endsWith('\n         GET https://x/login?a=1'));
    expect(formatStep(passedStep(1, 'Log in', url: 'https://x/login'), plain), isNot(contains('https://x')));
  });

  test('the summary counts flows and steps and gives the time', () {
    expect(
      formatSummary(sampleRun(), plain),
      '2 flows: 1 passed, 1 failed - 4 steps: 2 passed, 1 failed, 1 skipped - 1.4 s',
    );
  });

  test('the summary says "1 flow" for one', () {
    final run = RunReport(
      workspace: 'w',
      environment: null,
      startedAt: DateTime.utc(2026),
      duration: const Duration(milliseconds: 250),
      flows: [FlowReport(id: 'f', name: 'F', duration: Duration.zero, steps: [passedStep(1, 'x')])],
    );

    expect(formatSummary(run, plain), '1 flow: 1 passed, 0 failed - 1 step: 1 passed, 0 failed, 0 skipped - 0.3 s');
  });

  test('sensitive values never reach the text', () {
    final r = Redactor(['s3cret-value']);
    final step = failedStep(1, 'Login', failures: ['got "s3cret-value"']);

    expect(formatStep(step, r), isNot(contains('s3cret-value')));
    expect(formatStep(step, r), contains('got "***"'));
    expect(formatFlowHeader('s3cret-value flow', 1, r), isNot(contains('s3cret-value')));
    expect(formatStep(passedStep(1, 'x', url: 'https://x/?k=s3cret-value'), r, verbose: true), isNot(contains('s3cret-value')));
  });
}
