import '../models/assertion.dart';
import '../variables/interpolator.dart';
import 'flow_step_result.dart';
import 'value_extractor.dart';

/// Evaluates [assertion] against [response] (`{status, headers, body, ...}`),
/// resolving `{{variables}}` in the expected value from [variables]. Never
/// throws: an invalid path or regex comes back as a failed result, so one bad
/// assertion cannot break a flow run.
AssertionResult evaluateAssertion(
  Assertion assertion,
  Map<String, dynamic> response,
  Map<String, String> variables,
) {
  final path = assertion.field.trim();
  if (path != 'response' && !path.startsWith('response.')) {
    return _fail(assertion, null, 'Invalid field path "$path"');
  }

  final actual = extractValueAsString(response, path);
  final expected = interpolate(assertion.expected, variables);
  final op = assertion.operator;

  AssertionResult pass(bool condition) => condition
      ? AssertionResult(assertion: assertion, passed: true, actual: actual)
      : _fail(assertion, actual, _mismatch(assertion, expected, actual));

  switch (op) {
    case AssertionOperator.equals:
      return pass(actual == expected);
    case AssertionOperator.notEquals:
      return pass(actual != expected);
    case AssertionOperator.contains:
      return pass(actual != null && actual.contains(expected));
    case AssertionOperator.notContains:
      return pass(actual == null || !actual.contains(expected));
    case AssertionOperator.exists:
      return actual != null
          ? AssertionResult(assertion: assertion, passed: true, actual: actual)
          : _fail(assertion, actual, 'expected $path to exist');
    case AssertionOperator.notExists:
      return actual == null
          ? AssertionResult(assertion: assertion, passed: true, actual: actual)
          : _fail(assertion, actual, 'expected $path not to exist, got "${_shown(actual)}"');
    case AssertionOperator.matches:
      final RegExp regex;
      try {
        regex = RegExp(expected);
      } on FormatException {
        return _fail(assertion, actual, 'Invalid regex "$expected"');
      }
      return pass(actual != null && regex.hasMatch(actual));
    case AssertionOperator.greaterThan:
    case AssertionOperator.lessThan:
      if (actual == null) return pass(false);
      final left = num.tryParse(actual);
      if (left == null) return _fail(assertion, actual, '"${_shown(actual)}" is not a number');
      final right = num.tryParse(expected);
      if (right == null) return _fail(assertion, actual, '"$expected" is not a number');
      return pass(op == AssertionOperator.greaterThan ? left > right : left < right);
  }
}

String _mismatch(Assertion assertion, String expected, String? actual) =>
    'expected ${assertion.describe(expected: expected)}, got "${_shown(actual) ?? 'null'}"';

/// How many characters of the value an assertion saw are quoted in a message.
/// [AssertionResult.actual] keeps the whole value; the message only has to say
/// enough to recognise it (a body can be megabytes).
const int _maxQuotedChars = 200;

String? _shown(String? value) =>
    value != null && value.length > _maxQuotedChars ? '${value.substring(0, _maxQuotedChars)}…' : value;

AssertionResult _fail(Assertion assertion, String? actual, String message) =>
    AssertionResult(assertion: assertion, passed: false, actual: actual, message: 'Assertion failed: $message');
