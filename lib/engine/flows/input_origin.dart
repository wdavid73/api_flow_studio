import '../models/models.dart';

/// Names the session adds to the variables of every request it sends.
const List<String> sessionVariableNames = ['session_access_token', 'session_refresh_token'];

/// Where the value of one `{{name}}` input of a step comes from when the flow
/// runs.
sealed class InputOrigin {
  const InputOrigin();
}

/// An earlier step extracts it from its response, at [path].
final class FromStep extends InputOrigin {
  const FromStep(this.stepIndex, this.path);

  final int stepIndex;
  final String path;

  @override
  bool operator ==(Object other) => other is FromStep && other.stepIndex == stepIndex && other.path == path;

  @override
  int get hashCode => Object.hash(stepIndex, path);
}

/// The active environment defines it.
final class FromEnvironment extends InputOrigin {
  const FromEnvironment();
}

/// The login session provides it (`session_access_token`…).
final class FromSession extends InputOrigin {
  const FromSession();
}

/// Nothing provides it: the request would be sent with `{{name}}` as written.
final class Missing extends InputOrigin {
  const Missing();
}

/// Where [name], used by the step at [stepIndex], takes its value from, with
/// the same precedence the runner applies: the run's pool starts from the
/// environment and every step's extracts are written over it, and the session
/// only fills names the environment leaves free. A step's own extracts are
/// computed after it is sent, so they never feed its own inputs.
InputOrigin resolveInputOrigin(
  Flow flow,
  int stepIndex,
  String name,
  Map<String, String> environmentVariables,
) {
  for (var j = stepIndex - 1; j >= 0; j--) {
    final path = flow.steps[j].extract[name];
    if (path != null) return FromStep(j, path);
  }
  if (environmentVariables.containsKey(name)) return const FromEnvironment();
  if (sessionVariableNames.contains(name)) return const FromSession();
  return const Missing();
}
