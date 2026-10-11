import 'package:api_flow_studio/cli/redactor.dart';
import 'package:api_flow_studio/cli/reporters/junit_reporter.dart';
import 'package:api_flow_studio/cli/run_report.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  final plain = Redactor();

  RunReport runOf(List<StepReport> steps, {String flowName = 'Flow'}) => RunReport(
        workspace: 'ws',
        environment: 'qa',
        startedAt: DateTime.utc(2026),
        duration: const Duration(seconds: 1),
        flows: [FlowReport(id: 'f', name: flowName, steps: steps, duration: const Duration(milliseconds: 500))],
      );

  test('one testsuite per flow and one testcase per step, with totals', () {
    final xml = junitReport(sampleRun(), plain);

    expect(xml, startsWith('<?xml version="1.0" encoding="UTF-8"?>\n<testsuites name="commodo" tests="4" failures="1" errors="0" skipped="1" time="1.400">'));
    expect(xml, contains('<testsuite name="Signup" tests="3" failures="1" errors="0" skipped="1" time="0.900">'));
    expect(xml, contains('<testsuite name="Smoke" tests="1" failures="0" errors="0" skipped="0" time="0.500">'));
    expect(xml, contains('<testcase classname="Signup" name="1. Log in" time="0.120"/>'));
    expect(xml.trimRight(), endsWith('</testsuites>'));
  });

  test('a failed assertion is a failure with every message', () {
    final xml = junitReport(
      runOf([failedStep(1, 'Create', failures: ['Assertion failed: a', 'Assertion failed: b'])]),
      plain,
    );

    expect(
      xml,
      contains(
        '<testcase classname="Flow" name="1. Create" time="0.045">\n'
        '      <failure message="Assertion failed: a" type="AssertionFailure">Assertion failed: a\n'
        'Assertion failed: b</failure>\n'
        '    </testcase>',
      ),
    );
  });

  test('a network or configuration failure is an error with its type', () {
    final network = junitReport(runOf([failedStep(1, 'Ping', kind: FailureKind.network, failures: ['Connection refused'])]), plain);
    final config = junitReport(runOf([failedStep(1, 'Ping', kind: FailureKind.configuration, failures: ['Endpoint "x" not found'])]), plain);

    expect(network, contains('<error message="Connection refused" type="NetworkError">Connection refused</error>'));
    expect(network, contains('errors="1"'));
    expect(network, contains('failures="0"'));
    expect(config, contains('type="ConfigurationError"'));
  });

  test('a skipped step is <skipped/>', () {
    expect(junitReport(runOf([skippedStep(1, 'Later')]), plain), contains('name="1. Later" time="0.000">\n      <skipped/>\n    </testcase>'));
  });

  test('text is escaped so the file stays well-formed', () {
    final xml = junitReport(
      runOf([failedStep(1, 'a & b <c> "d"', failures: ['x < y & "z" \'w\''])], flowName: 'Flow <1>'),
      plain,
    );

    expect(xml, contains('name="Flow &lt;1&gt;"'));
    expect(xml, contains('name="1. a &amp; b &lt;c&gt; &quot;d&quot;"'));
    expect(xml, contains('message="x &lt; y &amp; &quot;z&quot; &apos;w&apos;"'));
    expect(xml, contains('>x &lt; y &amp; "z" \'w\'</failure>'));
  });

  test('control characters that XML forbids are dropped', () {
    final xml = junitReport(runOf([failedStep(1, 'x', failures: ['bad\u0000\u0008char'])]), plain);

    expect(xml, contains('badchar'));
    expect(xml, isNot(contains('\u0000')));
  });

  test('sensitive values are masked before escaping', () {
    final xml = junitReport(
      runOf([failedStep(1, 'Login', failures: ['got "a&b-secret"'])]),
      Redactor(['a&b-secret']),
    );

    expect(xml, isNot(contains('a&b-secret')));
    expect(xml, isNot(contains('a&amp;b-secret')));
    expect(xml, contains('got &quot;***&quot;'));
  });
}
