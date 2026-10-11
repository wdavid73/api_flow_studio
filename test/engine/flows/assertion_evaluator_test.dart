import 'package:api_flow_studio/engine/flows/assertion_evaluator.dart';
import 'package:api_flow_studio/engine/flows/flow_step_result.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const response = <String, dynamic>{
    'status': 201,
    'headers': {'content-type': 'application/json'},
    'body': {
      'data': {'id': 'u-1', 'email': 'ana@test.com', 'age': 30, 'score': -1.5, 'tags': ['a', 'b']},
      'empty': '',
    },
    'elapsedMs': 120,
    'sizeBytes': 512,
  };

  AssertionResult run(
    String field,
    AssertionOperator op, [
    String expected = '',
    Map<String, String> variables = const {},
  ]) =>
      evaluateAssertion(Assertion(field: field, operator: op, expected: expected), response, variables);

  group('equals', () {
    test('passes on an exact match', () {
      final r = run('response.status', AssertionOperator.equals, '201');
      expect(r.passed, isTrue);
      expect(r.actual, '201');
      expect(r.message, isNull);
    });

    test('fails with the expected and actual values in the message', () {
      final r = run('response.status', AssertionOperator.equals, '200');
      expect(r.passed, isFalse);
      expect(r.message, 'Assertion failed: expected response.status == "200", got "201"');
    });

    test('is case sensitive', () {
      expect(run('response.body.data.email', AssertionOperator.equals, 'ANA@test.com').passed, isFalse);
    });

    test('fails on a missing value and says got "null"', () {
      final r = run('response.body.nope', AssertionOperator.equals, 'x');
      expect(r.passed, isFalse);
      expect(r.actual, isNull);
      expect(r.message, contains('got "null"'));
    });

    test('an empty expected matches an empty string but not a missing value', () {
      expect(run('response.body.empty', AssertionOperator.equals, '').passed, isTrue);
      expect(run('response.body.nope', AssertionOperator.equals, '').passed, isFalse);
    });

    test('the expected value may use {{variables}}', () {
      final r = run('response.body.data.id', AssertionOperator.equals, '{{user_id}}', {'user_id': 'u-1'});
      expect(r.passed, isTrue);
    });
  });

  group('notEquals', () {
    test('passes when different and when the value is missing', () {
      expect(run('response.status', AssertionOperator.notEquals, '500').passed, isTrue);
      expect(run('response.body.nope', AssertionOperator.notEquals, 'x').passed, isTrue);
    });

    test('fails when equal', () {
      final r = run('response.status', AssertionOperator.notEquals, '201');
      expect(r.passed, isFalse);
      expect(r.message, 'Assertion failed: expected response.status != "201", got "201"');
    });
  });

  group('contains / notContains', () {
    test('contains passes and fails', () {
      expect(run('response.body.data.email', AssertionOperator.contains, '@test').passed, isTrue);
      expect(run('response.body.data.email', AssertionOperator.contains, 'zzz').passed, isFalse);
    });

    test('contains fails on a missing value, notContains passes', () {
      expect(run('response.body.nope', AssertionOperator.contains, 'x').passed, isFalse);
      expect(run('response.body.nope', AssertionOperator.notContains, 'x').passed, isTrue);
    });

    test('notContains fails when the text is present', () {
      final r = run('response.body.data.email', AssertionOperator.notContains, 'ana');
      expect(r.passed, isFalse);
      expect(r.message, contains('not contains "ana"'));
    });

    test('contains works on a JSON-encoded list', () {
      expect(run('response.body.data.tags', AssertionOperator.contains, '"b"').passed, isTrue);
    });
  });

  group('exists / notExists', () {
    test('exists passes for a present value and ignores expected', () {
      expect(run('response.body.data.id', AssertionOperator.exists, 'whatever').passed, isTrue);
    });

    test('exists fails for a missing value', () {
      final r = run('response.body.nope', AssertionOperator.exists);
      expect(r.passed, isFalse);
      expect(r.message, 'Assertion failed: expected response.body.nope to exist');
    });

    test('notExists passes for a missing value and fails for a present one', () {
      expect(run('response.body.nope', AssertionOperator.notExists).passed, isTrue);
      final r = run('response.body.data.id', AssertionOperator.notExists);
      expect(r.passed, isFalse);
      expect(r.message, 'Assertion failed: expected response.body.data.id not to exist, got "u-1"');
    });
  });

  group('matches', () {
    test('passes when the regex matches anywhere', () {
      expect(run('response.body.data.email', AssertionOperator.matches, r'^\w+@test\.com$').passed, isTrue);
    });

    test('fails when it does not match, and on a missing value', () {
      expect(run('response.body.data.email', AssertionOperator.matches, r'^\d+$').passed, isFalse);
      expect(run('response.body.nope', AssertionOperator.matches, '.*').passed, isFalse);
    });

    test('an invalid regex is a failed result, not an exception', () {
      final r = run('response.status', AssertionOperator.matches, '(');
      expect(r.passed, isFalse);
      expect(r.message, 'Assertion failed: Invalid regex "("');
    });
  });

  group('greaterThan / lessThan', () {
    test('compare numbers, including decimals and negatives', () {
      expect(run('response.elapsedMs', AssertionOperator.lessThan, '800').passed, isTrue);
      expect(run('response.elapsedMs', AssertionOperator.greaterThan, '100').passed, isTrue);
      expect(run('response.body.data.score', AssertionOperator.lessThan, '0').passed, isTrue);
      expect(run('response.body.data.score', AssertionOperator.greaterThan, '-2.5').passed, isTrue);
    });

    test('fail when the order does not hold, including equality', () {
      expect(run('response.elapsedMs', AssertionOperator.lessThan, '120').passed, isFalse);
      expect(run('response.elapsedMs', AssertionOperator.greaterThan, '120').passed, isFalse);
    });

    test('a non-numeric actual value fails with a clear message', () {
      final r = run('response.body.data.email', AssertionOperator.greaterThan, '1');
      expect(r.passed, isFalse);
      expect(r.message, 'Assertion failed: "ana@test.com" is not a number');
    });

    test('a non-numeric expected value fails with a clear message', () {
      final r = run('response.elapsedMs', AssertionOperator.lessThan, 'fast');
      expect(r.passed, isFalse);
      expect(r.message, 'Assertion failed: "fast" is not a number');
    });

    test('a missing value fails', () {
      expect(run('response.body.nope', AssertionOperator.lessThan, '5').passed, isFalse);
    });
  });

  group('paths', () {
    test('a path that does not start with response is a failed result, not an exception', () {
      final r = run('body.data.id', AssertionOperator.exists);
      expect(r.passed, isFalse);
      expect(r.message, 'Assertion failed: Invalid field path "body.data.id"');
    });

    test('surrounding spaces in the path are ignored', () {
      expect(run('  response.status  ', AssertionOperator.equals, '201').passed, isTrue);
    });

    test('elapsedMs and sizeBytes are reachable', () {
      expect(run('response.sizeBytes', AssertionOperator.equals, '512').passed, isTrue);
    });

    test('a bare "response" path is valid', () {
      expect(run('response', AssertionOperator.exists).passed, isTrue);
    });
  });

  group('long actual values', () {
    final big = 'x' * 5000;
    final bigResponse = <String, dynamic>{'status': 200, 'body': big};

    AssertionResult runBig(AssertionOperator op, [String expected = 'y']) => evaluateAssertion(
          Assertion(field: 'response.body', operator: op, expected: expected),
          bigResponse,
          const {},
        );

    test('are cut in the message but kept whole in the result', () {
      final r = runBig(AssertionOperator.equals);

      expect(r.actual, big);
      expect(r.message!.length, lessThan(400));
      expect(r.message, contains('…'));
      expect(r.message, startsWith('Assertion failed: expected response.body == "y", got "${'x' * 200}'));
    });

    test('are cut in every message that quotes them', () {
      expect(runBig(AssertionOperator.notExists).message!.length, lessThan(400));
      expect(runBig(AssertionOperator.greaterThan, '1').message!.length, lessThan(400));
    });

    test('a value of exactly the limit is not cut', () {
      final exact = 'x' * 200;
      final r = evaluateAssertion(
        const Assertion(field: 'response.body', expected: 'y'),
        {'body': exact},
        const {},
      );
      expect(r.message, contains('got "$exact"'));
      expect(r.message, isNot(contains('…')));
    });
  });

  group('Assertion', () {
    test('isConfigured is false for an empty or blank field', () {
      expect(const Assertion(field: '').isConfigured, isFalse);
      expect(const Assertion(field: '   ').isConfigured, isFalse);
      expect(const Assertion(field: 'response.status').isConfigured, isTrue);
    });

    test('defaults to equals with an empty expected', () {
      const a = Assertion(field: 'response.status');
      expect(a.operator, AssertionOperator.equals);
      expect(a.expected, '');
    });

    test('round-trips through JSON for every operator', () {
      for (final op in AssertionOperator.values) {
        final a = Assertion(field: 'response.x', operator: op, expected: 'v');
        expect(Assertion.fromJson(a.toJson()), a, reason: op.name);
      }
    });

    test('every operator has a label', () {
      expect(AssertionOperator.values.map((o) => o.label).toSet(), hasLength(AssertionOperator.values.length));
    });
  });
}
