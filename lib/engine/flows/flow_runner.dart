import '../http/request_executor.dart';
import '../models/models.dart';
import 'flow_step_result.dart';
import 'value_extractor.dart';

/// Runs a [Flow]'s steps in order against a single accumulating variable
/// pool (seeded from the active environment), one [RequestExecutor] call
/// per step -- the same entrypoint the manual request builder uses, so a
/// flow step behaves exactly like sending that request by hand would.
///
/// Per step: resolve its [FlowStep.endpointId] to a real [Endpoint],
/// execute it, extract [FlowStep.extract] variables into the pool
/// (visible to every later step, not just the next one), and evaluate
/// [FlowStep.assertField]/[FlowStep.assertExpected] if set -- with no
/// assertion configured, "the transport call didn't error" is success on
/// its own (Architecture Decision #7). A failing step with
/// [FlowStep.stopOnFailure] marks every remaining step
/// [FlowStepStatus.skipped] without executing them.
class FlowRunner {
  // ignore: prefer_initializing_formals
  FlowRunner({required RequestExecutor executor}) : _executor = executor;

  final RequestExecutor _executor;

  Future<FlowRunResult> run(
    Flow flow, {
    required Map<String, Endpoint> endpoints,
    required Map<String, String> initialVariables,
  }) async {
    final results = <FlowStepResult>[];
    final variables = {...initialVariables};
    var stopped = false;

    for (final step in flow.steps) {
      if (stopped) {
        results.add(const FlowStepResult(status: FlowStepStatus.skipped));
        continue;
      }

      final endpoint = endpoints[step.endpointId];
      if (endpoint == null) {
        results.add(FlowStepResult(
          status: FlowStepStatus.failure,
          failureReason: 'Endpoint "${step.endpointId}" not found',
        ));
        if (step.stopOnFailure) stopped = true;
        continue;
      }

      final response = await _executor.execute(endpoint, variables: variables);

      if (response.error != null) {
        results.add(FlowStepResult(
          status: FlowStepStatus.failure,
          response: response,
          failureReason: response.error,
        ));
        if (step.stopOnFailure) stopped = true;
        continue;
      }

      final responseMap = <String, dynamic>{
        'status': response.status,
        'headers': response.headers,
        'body': response.body,
      };

      final extracted = <String, String>{};
      for (final entry in step.extract.entries) {
        final value = extractValueAsString(responseMap, entry.value);
        if (value != null) {
          extracted[entry.key] = value;
          variables[entry.key] = value;
        }
      }

      String? failureReason;
      if (step.assertField != null && step.assertExpected != null) {
        final actual = extractValueAsString(responseMap, step.assertField!);
        if (actual != step.assertExpected) {
          failureReason = 'Assertion failed: expected "${step.assertExpected}" '
              'for ${step.assertField}, got "${actual ?? 'null'}"';
        }
      }

      if (failureReason != null) {
        results.add(FlowStepResult(
          status: FlowStepStatus.failure,
          response: response,
          extractedVariables: extracted,
          failureReason: failureReason,
        ));
        if (step.stopOnFailure) stopped = true;
      } else {
        results.add(FlowStepResult(
          status: FlowStepStatus.success,
          response: response,
          extractedVariables: extracted,
        ));
      }
    }

    return FlowRunResult(stepResults: results);
  }
}
