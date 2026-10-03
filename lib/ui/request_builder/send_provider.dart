import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../engine/http/executed_response.dart';
import '../../engine/models/models.dart';
import '../environments/environments_provider.dart';
import '../history/all_history_provider.dart';
import '../history/history_provider.dart';
import '../projects/projects_provider.dart';
import '../response_viewer/response_body_tab.dart' show rawResponseBody;
import '../session/session_provider.dart' show sessionExecutorProvider;
import 'request_draft_provider.dart';

export 'request_executor_provider.dart' show requestExecutorProvider;

class SendState {
  const SendState({this.loading = false, this.response});

  final bool loading;
  final ExecutedResponse? response;
}

class SendNotifier extends Notifier<SendState> {
  /// The active project right now. `ref` cannot be read between a project change
  /// and the rebuild it causes, so a send that outlives a switch compares
  /// against this instead.
  late String _projectId;

  @override
  SendState build() {
    _projectId = ref.watch(activeProjectIdProvider); // a response belongs to one project
    ref.listen(activeProjectIdProvider, (_, next) => _projectId = next);
    return const SendState();
  }

  Future<void> send() async {
    // The project the request was sent from: if the user switches while it is
    // in flight, its history still goes to this project's store and nothing is
    // shown in the new one.
    final projectId = _projectId;
    final store = ref.read(jsonStoreProvider);
    state = SendState(loading: true, response: state.response);
    final endpoint = ref.read(requestDraftProvider);
    final executor = ref.read(sessionExecutorProvider);
    // Reads whichever environment is active *right now* -- switching
    // environments and resending the same draft must resolve against the
    // new environment's values (SPEC criterion #2), not whatever was
    // active when send() was first wired up.
    final variables = ref.read(environmentsProvider).value?.active?.resolvedVariables ?? const {};
    final response = await executor.execute(endpoint, variables: variables);
    if (_projectId == projectId) state = SendState(response: response);

    // Only a *saved* endpoint (a real persisted id, not the blank-draft
    // sentinel) gets history -- there's nowhere meaningful to attach it
    // for an endpoint that was never saved into a collection.
    if (endpoint.id != draftEndpointId) {
      await store.appendHistoryEntry(
            endpoint.id,
            HistoryEntry(
              id: const Uuid().v4(),
              endpointId: endpoint.id,
              timestamp: DateTime.now(),
              status: response.status,
              headers: response.headers,
              body: response.error == null ? rawResponseBody(response.body) : null,
              elapsedMs: response.elapsedMs,
              error: response.error,
            ),
          );
      if (_projectId == projectId) {
        ref.invalidate(historyProvider(endpoint.id));
        ref.invalidate(allHistoryProvider);
      }
    }
  }
}

final sendStateProvider = NotifierProvider<SendNotifier, SendState>(SendNotifier.new);
