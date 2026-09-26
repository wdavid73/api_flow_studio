import 'package:freezed_annotation/freezed_annotation.dart';

import '../http/executed_response.dart';

part 'flow_step_result.freezed.dart';

enum FlowStepStatus { success, failure, skipped }

/// The outcome of one [FlowStep] within a [FlowRunResult]. [response] is
/// null only for a [FlowStepStatus.skipped] step (never executed) or a
/// step whose endpointId didn't resolve to a saved [Endpoint].
@freezed
class FlowStepResult with _$FlowStepResult {
  const factory FlowStepResult({
    required FlowStepStatus status,
    ExecutedResponse? response,
    @Default({}) Map<String, String> extractedVariables,
    String? failureReason,
  }) = _FlowStepResult;
}

/// The full result of running a Flow: one [FlowStepResult] per step, in
/// the same order as [Flow.steps].
@freezed
class FlowRunResult with _$FlowRunResult {
  const factory FlowRunResult({required List<FlowStepResult> stepResults}) = _FlowRunResult;
}
