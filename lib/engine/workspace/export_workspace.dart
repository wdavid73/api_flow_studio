import '../models/models.dart';
import '../projects/project.dart';
import '../storage/json_store.dart';
import 'workspace_file.dart';

/// Reads [project]'s data from [store] and returns it ready to be written to a
/// file: environments, collections, flows and host notes, with every secret
/// removed. Never included: history, the active environment, session tokens.
///
/// Removed: the value of every secret variable (its name and flag stay), and
/// literal credentials in a request's authentication (a bearer token or a basic
/// password; a `{{variable}}` reference is kept, it holds no secret).
Future<WorkspaceFile> exportWorkspace(
  JsonStore store,
  Project project, {
  DateTime Function()? now,
}) async {
  final environments = await store.readEnvironments();
  final collections = await store.readCollections();

  return WorkspaceFile(
    name: project.name,
    colorIndex: project.colorIndex,
    environments: [for (final env in environments) _withoutSecrets(env)],
    groups: collections.groups,
    endpoints: [for (final endpoint in collections.endpoints) _withoutCredentials(endpoint)],
    flows: await store.readFlows(),
    hostNotes: await store.readHostNotes(),
    exportedAt: (now ?? DateTime.now)(),
  );
}

Environment _withoutSecrets(Environment env) => env.copyWith(variables: {
      for (final entry in env.variables.entries)
        entry.key: entry.value.secret ? entry.value.copyWith(value: '') : entry.value,
    });

Endpoint _withoutCredentials(Endpoint endpoint) {
  final auth = endpoint.authConfig;
  final cleaned = switch (auth) {
    AuthConfigBearer(:final token) when _isLiteral(token) => const AuthConfig.bearer(token: ''),
    AuthConfigBasic(:final username, :final password) when _isLiteral(password) =>
      AuthConfig.basic(username: username, password: ''),
    _ => auth,
  };
  return identical(cleaned, auth) ? endpoint : endpoint.copyWith(authConfig: cleaned);
}

/// A value that is real text rather than empty or a `{{variable}}` reference.
bool _isLiteral(String value) => value.isNotEmpty && !value.contains('{{');
