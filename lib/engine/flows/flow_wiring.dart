import '../models/models.dart';
import 'input_origin.dart';
import 'step_inputs.dart';

/// What came of connecting a response field to an input.
sealed class ConnectResult {
  const ConnectResult();
}

/// The source step, with the extract that makes the connection.
final class Connected extends ConnectResult {
  const Connected(this.step);

  final FlowStep step;
}

/// A step between the two already extracts the same name, so the input would
/// keep taking its value from there: nothing was changed.
final class Shadowed extends ConnectResult {
  const Shadowed(this.stepIndex);

  final int stepIndex;
}

/// Connects the field at [path] of step [fromStep] to the `{{variable}}`
/// input of the later step [toStep]: the source step extracts [path] as
/// [variable] (replacing whatever path it extracted under that name before).
/// A connection is a plain extract -- the flow's model does not change shape.
ConnectResult connectField(
  Flow flow, {
  required int fromStep,
  required String path,
  required int toStep,
  required String variable,
}) {
  assert(fromStep < toStep, 'data only flows forward');
  for (var k = toStep - 1; k > fromStep; k--) {
    if (flow.steps[k].extract.containsKey(variable)) return Shadowed(k);
  }
  final source = flow.steps[fromStep];
  return Connected(source.copyWith(extract: {...source.extract, variable: path}));
}

/// Step [fromStep] without its extract of [variable]: every input it fed
/// loses that source.
FlowStep disconnectVariable(Flow flow, {required int fromStep, required String variable}) {
  final source = flow.steps[fromStep];
  return source.copyWith(extract: {...source.extract}..remove(variable));
}

/// How many later steps take [variable] from step [fromStep] -- the inputs a
/// disconnect would leave without a source.
int consumersOf(
  Flow flow,
  Map<String, Endpoint> endpoints,
  Map<String, String> environmentVariables, {
  required int fromStep,
  required String variable,
}) {
  var count = 0;
  for (var i = fromStep + 1; i < flow.steps.length; i++) {
    final endpoint = endpoints[flow.steps[i].endpointId];
    if (endpoint == null || !stepInputs(endpoint).variables.contains(variable)) continue;
    final origin = resolveInputOrigin(flow, i, variable, environmentVariables);
    if (origin is FromStep && origin.stepIndex == fromStep) count++;
  }
  return count;
}
