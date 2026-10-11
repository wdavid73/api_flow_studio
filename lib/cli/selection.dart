import '../engine/models/environment_kind.dart';
import '../engine/models/models.dart';
import '../engine/workspace/workspace_file.dart';
import 'cli_options.dart';

/// Prefix of the process environment variables that set a flow variable:
/// `AFS_VAR_api_key=...` sets `api_key`.
const String processVariablePrefix = 'AFS_VAR_';

/// What to run: the environment, the flows in the order to run them, and the
/// variables every flow starts from.
class RunSelection {
  const RunSelection({
    required this.environment,
    required this.flows,
    required this.variables,
    required this.secretNames,
    required this.overrides,
    required this.emptySecrets,
  });

  /// Null when the workspace has none.
  final Environment? environment;
  final List<Flow> flows;

  /// The environment's variables with [overrides] applied.
  final Map<String, String> variables;

  /// Variables the environment marks secret.
  final Set<String> secretNames;

  /// Values given from outside the file (`AFS_VAR_*` and `--var`).
  final Map<String, String> overrides;

  /// Secret variables that still have no value after [overrides].
  final List<String> emptySecrets;
}

/// The selection cannot be made; [message] says why, in plain words.
class SelectionError {
  const SelectionError(this.message);

  final String message;
}

/// Chooses the environment and flows [options] ask for out of [file] and builds
/// the starting variables: environment, then `AFS_VAR_*` from [processEnv], then
/// `--var`, each overriding the one before. Returns a [RunSelection] or a
/// [SelectionError]; nothing is sent or written here.
Object selectRun(WorkspaceFile file, CliOptions options, Map<String, String> processEnv) {
  final environment = _pickEnvironment(file.environments, options.env);
  if (environment is SelectionError) return environment;
  final chosen = environment as Environment?;

  if (chosen != null && isProductionEnvironment(chosen.name) && !options.allowProduction) {
    return SelectionError(
      'environment "${chosen.name}" looks like production; pass --allow-production to run against it',
    );
  }

  final flows = _pickFlows(file.flows, options.flows);
  if (flows is SelectionError) return flows;

  final overrides = <String, String>{
    for (final entry in processEnv.entries)
      if (entry.key.length > processVariablePrefix.length && entry.key.startsWith(processVariablePrefix))
        entry.key.substring(processVariablePrefix.length): entry.value,
    ...options.vars,
  };
  final variables = {...?chosen?.resolvedVariables, ...overrides};
  final secretNames = {
    for (final entry in chosen?.variables.entries ?? const <MapEntry<String, EnvironmentVariable>>[])
      if (entry.value.secret) entry.key,
  };

  return RunSelection(
    environment: chosen,
    flows: flows as List<Flow>,
    variables: variables,
    secretNames: secretNames,
    overrides: overrides,
    emptySecrets: [
      for (final name in secretNames)
        if ((variables[name] ?? '').isEmpty) name,
    ],
  );
}

Object? _pickEnvironment(List<Environment> environments, String? name) {
  final names = environments.map((e) => e.name).join(', ');
  if (name == null) {
    if (environments.length > 1) {
      return SelectionError('the workspace has several environments ($names); choose one with --env');
    }
    return environments.isEmpty ? null : environments.single;
  }
  for (final environment in environments) {
    if (environment.name.toLowerCase() == name.toLowerCase()) return environment;
  }
  return SelectionError('environment "$name" not found; available: ${names.isEmpty ? '(none)' : names}');
}

Object _pickFlows(List<Flow> flows, List<String> wanted) {
  if (flows.isEmpty) return const SelectionError('the workspace has no flows; nothing to run');
  if (wanted.isEmpty) return flows;

  final picked = <Flow>[];
  for (final key in wanted) {
    final byId = flows.where((f) => f.id == key).toList();
    final matches = byId.isNotEmpty ? byId : flows.where((f) => f.name.toLowerCase() == key.toLowerCase()).toList();
    if (matches.isEmpty) {
      return SelectionError('flow "$key" not found; available: ${flows.map((f) => f.name).join(', ')}');
    }
    if (matches.length > 1) {
      return SelectionError(
        'flow name "$key" matches ${matches.length} flows; use the id instead (${matches.map((f) => f.id).join(', ')})',
      );
    }
    if (!picked.contains(matches.single)) picked.add(matches.single);
  }
  return picked;
}
