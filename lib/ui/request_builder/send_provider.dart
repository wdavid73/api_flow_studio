import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../engine/http/executed_response.dart';
import '../../engine/models/models.dart';
import '../environments/environments_provider.dart';
import '../history/all_history_provider.dart';
import '../history/history_provider.dart';
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
  @override
  SendState build() => const SendState();

  Future<void> send() async {
    state = SendState(loading: true, response: state.response);
    final endpoint = ref.read(requestDraftProvider);
    final executor = ref.read(sessionExecutorProvider);
    // Reads whichever environment is active *right now* -- switching
    // environments and resending the same draft must resolve against the
    // new environment's values (SPEC criterion #2), not whatever was
    // active when send() was first wired up.
    final variables = ref.read(environmentsProvider).value?.active?.resolvedVariables ?? const {};
    final response = await executor.execute(endpoint, variables: variables);
    state = SendState(response: response);

    // Only a *saved* endpoint (a real persisted id, not the blank-draft
    // sentinel) gets history -- there's nowhere meaningful to attach it
    // for an endpoint that was never saved into a collection.
    if (endpoint.id != draftEndpointId) {
      await ref.read(jsonStoreProvider).appendHistoryEntry(
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
      ref.invalidate(historyProvider(endpoint.id));
      ref.invalidate(allHistoryProvider);
    }
  }
}

final sendStateProvider = NotifierProvider<SendNotifier, SendState>(SendNotifier.new);
