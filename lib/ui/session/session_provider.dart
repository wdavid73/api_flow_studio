import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/http/request_executor.dart';
import '../../engine/session/session.dart';
import '../../engine/session/session_request_executor.dart';
import '../environments/environments_provider.dart';
import '../projects/projects_provider.dart';
import '../request_builder/request_executor_provider.dart';
import '../shell/app_toast.dart';

/// Key of the session used when no environment is active.
const String noEnvironmentKey = '';

/// One [Session] per environment id, in memory only: nothing here is ever
/// written to disk, so every token is gone when the app closes.
class SessionsNotifier extends Notifier<Map<String, Session>> {
  @override
  Map<String, Session> build() {
    // Environment ids are per project, so each session already belongs to one;
    // only the shared "no environment" slot has to be dropped on a switch.
    ref.listen(activeProjectIdProvider, (_, _) {
      if (state.containsKey(noEnvironmentKey)) state = {...state}..remove(noEnvironmentKey);
    });
    return const {};
  }

  /// The session of [environmentKey] (an environment id or [noEnvironmentKey]),
  /// empty if none exists yet.
  Session sessionFor(String environmentKey) => state[environmentKey] ?? const Session();

  void update(String environmentKey, Session session) {
    state = {...state, environmentKey: session};
  }
}

final sessionsProvider = NotifierProvider<SessionsNotifier, Map<String, Session>>(SessionsNotifier.new);

/// The id of the active environment, or [noEnvironmentKey] when there is none.
final activeEnvironmentKeyProvider = Provider<String>(
  (ref) => ref.watch(environmentsProvider.select((async) => async.value?.activeEnvironmentId)) ?? noEnvironmentKey,
);

/// The session of the active environment.
final activeSessionProvider = Provider<Session>(
  (ref) => ref.watch(sessionsProvider)[ref.watch(activeEnvironmentKeyProvider)] ?? const Session(),
);

/// The executor the app sends with: [requestExecutorProvider] (the real HTTP
/// executor, which tests override) wrapped with the active environment's
/// session. The environment is fixed when this instance is built, so a request
/// already in flight stores its tokens where it started even if the user
/// switches environment before it returns.
final sessionExecutorProvider = Provider<RequestExecutor>((ref) {
  final environmentKey = ref.watch(activeEnvironmentKeyProvider);
  return SessionRequestExecutor(
    inner: ref.watch(requestExecutorProvider),
    readSession: () => ref.read(sessionsProvider.notifier).sessionFor(environmentKey),
    writeSession: (session) => ref.read(sessionsProvider.notifier).update(environmentKey, session),
    onTokensCaptured: () {
      final environments = ref.read(environmentsProvider).value?.environments ?? const [];
      final name = environments.where((e) => e.id == environmentKey).firstOrNull?.name ?? 'No environment';
      // Only the environment name: a toast must never carry a token.
      ref.read(toastProvider.notifier).show('Tokens captured for $name');
    },
  );
});

/// What `{{variable}}` resolves against in the UI: the active environment's
/// variables plus the session's `session_*` ones. An environment variable
/// with the same name wins.
final effectiveVariablesProvider = Provider<Map<String, String>>((ref) {
  final environmentVariables = ref.watch(environmentsProvider).value?.active?.resolvedVariables ?? const {};
  return {...sessionVariables(ref.watch(activeSessionProvider)), ...environmentVariables};
});
