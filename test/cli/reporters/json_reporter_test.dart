import 'dart:convert';

import 'package:api_flow_studio/cli/redactor.dart';
import 'package:api_flow_studio/cli/reporters/json_reporter.dart';
import 'package:api_flow_studio/cli/run_report.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  Map<String, dynamic> decode(String text) => jsonDecode(text) as Map<String, dynamic>;

  test('the top level carries the workspace, environment, times and the summary', () {
    final json = decode(jsonReport(sampleRun(), Redactor()));

    expect(json['workspace'], 'commodo');
    expect(json['environment'], 'qa');
    expect(json['startedAt'], '2026-10-11T14:03:22.000Z');
    expect(json['durationMs'], 1400);
    expect(json['summary'], {'flows': 2, 'flowsFailed': 1, 'steps': 4, 'stepsFailed': 1, 'stepsSkipped': 1});
  });

  test('each flow has its status and steps', () {
    final flows = decode(jsonReport(sampleRun(), Redactor()))['flows'] as List;

    expect(flows[0]['id'], 'f-signup');
    expect(flows[0]['name'], 'Signup');
    expect(flows[0]['status'], 'failed');
    expect(flows[0]['durationMs'], 900);
    expect(flows[1]['status'], 'passed');
    expect((flows[0]['steps'] as List).length, 3);
  });

  test('a passing step lists its assertions without detail', () {
    final step = ((decode(jsonReport(sampleRun(), Redactor()))['flows'] as List)[0]['steps'] as List)[0] as Map;

    expect(step, {
      'index': 1,
      'endpoint': 'Log in',
      'method': 'GET',
      'status': 'passed',
      'httpStatus': 200,
      'elapsedMs': 120,
      'assertions': [
        {'check': 'response.status == "200"', 'passed': true},
      ],
    });
  });

  test('a failed step adds its kind, failures and the detail of each failed assertion', () {
    final step = ((decode(jsonReport(sampleRun(), Redactor()))['flows'] as List)[0]['steps'] as List)[1] as Map;

    expect(step['status'], 'failed');
    expect(step['failureKind'], 'assertion');
    expect(step['failures'], ['Assertion failed: expected response.status == "201", got "404"']);
    expect(step['assertions'], [
      {
        'check': 'response.status == "201"',
        'passed': false,
        'actual': '404',
        'message': 'Assertion failed: expected response.status == "201", got "404"',
      },
    ]);
  });

  test('a skipped step has no httpStatus', () {
    final step = ((decode(jsonReport(sampleRun(), Redactor()))['flows'] as List)[0]['steps'] as List)[2] as Map;

    expect(step['status'], 'skipped');
    expect(step.containsKey('httpStatus'), isFalse);
    expect(step.containsKey('failures'), isFalse);
  });

  test('no environment is null', () {
    final run = RunReport(workspace: 'w', environment: null, startedAt: DateTime.utc(2026), duration: Duration.zero, flows: const []);

    expect(decode(jsonReport(run, Redactor()))['environment'], isNull);
  });

  test('sensitive values are masked in every string, including ones JSON would escape', () {
    final run = RunReport(
      workspace: 'w',
      environment: 'qa',
      startedAt: DateTime.utc(2026),
      duration: Duration.zero,
      flows: [
        FlowReport(id: 'f', name: 'F', duration: Duration.zero, steps: [
          failedStep(1, 'Login', failures: ['got "line1\nse"cret-value"']),
        ]),
      ],
    );

    final text = jsonReport(run, Redactor(['line1\nse"cret-value']));

    expect(text, isNot(contains('cret-value')));
    expect(decode(text)['flows'][0]['steps'][0]['failures'], ['got "***"']);
  });

  test('the output is indented and ends with a newline', () {
    final text = jsonReport(sampleRun(), Redactor());

    expect(text, contains('\n  "workspace": "commodo"'));
    expect(text, endsWith('\n'));
  });
}
