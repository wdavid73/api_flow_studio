import 'package:freezed_annotation/freezed_annotation.dart';

part 'assertion.freezed.dart';
part 'assertion.g.dart';

/// How a flow step compares the value found at [Assertion.field] with
/// [Assertion.expected].
enum AssertionOperator {
  equals('=='),
  notEquals('!='),
  contains('contains'),
  notContains('not contains'),
  exists('exists'),
  notExists('not exists'),
  matches('matches'),
  greaterThan('>'),
  lessThan('<');

  const AssertionOperator(this.label);

  /// The symbol or words shown in the UI and in failure messages.
  final String label;

  /// Whether [Assertion.expected] means anything for this operator.
  bool get takesExpected => this != exists && this != notExists;
}

/// One check on a flow step's response: the value at [field] (a dot path
/// starting with `response`, like `response.body.data.id`) compared with
/// [expected] using [operator].
@freezed
class Assertion with _$Assertion {
  const Assertion._();

  const factory Assertion({
    required String field,
    @Default(AssertionOperator.equals) AssertionOperator operator,
    @Default('') String expected,
  }) = _Assertion;

  factory Assertion.fromJson(Map<String, dynamic> json) => _$AssertionFromJson(json);

  /// A blank field means the row was never filled in: it is skipped, never failed.
  bool get isConfigured => field.trim().isNotEmpty;

  /// The check in words: `response.status == "200"`, `response.body.id exists`.
  /// Pass [expected] to show it with its `{{variables}}` already resolved.
  String describe({String? expected}) {
    final path = field.trim();
    return operator.takesExpected ? '$path ${operator.label} "${expected ?? this.expected}"' : '$path ${operator.label}';
  }
}
