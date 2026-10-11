import 'package:freezed_annotation/freezed_annotation.dart';

import 'assertion.dart';

part 'flow_step.freezed.dart';
part 'flow_step.g.dart';

@freezed
class FlowStep with _$FlowStep {
  const factory FlowStep({
    required String endpointId,
    @Default({}) Map<String, String> extract, // variable -> dot-path
    @Default([]) List<Assertion> assertions,
    @Default(true) bool stopOnFailure,
  }) = _FlowStep;

  /// Reads a step, turning the single `assertField`/`assertExpected` pair that
  /// older versions wrote into one [Assertion]. The file is not rewritten: the
  /// new shape is saved the next time the flow is saved.
  factory FlowStep.fromJson(Map<String, dynamic> json) =>
      _$FlowStepFromJson(_migrateLegacyAssertion(json));
}

Map<String, dynamic> _migrateLegacyAssertion(Map<String, dynamic> json) {
  if (json.containsKey('assertions')) return json;
  final field = json['assertField'];
  final expected = json['assertExpected'];
  if (field is! String || field.isEmpty || expected is! String || expected.isEmpty) return json;
  return {
    ...json,
    'assertions': [Assertion(field: field, expected: expected).toJson()],
  };
}
