import 'package:freezed_annotation/freezed_annotation.dart';

part 'flow_step.freezed.dart';
part 'flow_step.g.dart';

@freezed
class FlowStep with _$FlowStep {
  const factory FlowStep({
    required String endpointId,
    @Default({}) Map<String, String> extract, // variable -> dot-path
    String? assertField,
    String? assertExpected,
    @Default(true) bool stopOnFailure,
  }) = _FlowStep;

  factory FlowStep.fromJson(Map<String, dynamic> json) =>
      _$FlowStepFromJson(json);
}
