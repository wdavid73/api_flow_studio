import 'package:freezed_annotation/freezed_annotation.dart';

import 'flow_step.dart';

part 'flow.freezed.dart';
part 'flow.g.dart';

@freezed
class Flow with _$Flow {
  const factory Flow({
    required String id,
    required String name,
    @Default([]) List<FlowStep> steps,
  }) = _Flow;

  factory Flow.fromJson(Map<String, dynamic> json) => _$FlowFromJson(json);
}
