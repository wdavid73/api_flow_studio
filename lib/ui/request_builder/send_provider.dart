import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../engine/http/executed_response.dart';
import '../../engine/http/request_executor.dart';
import '../../engine/models/models.dart';
import '../environments/environments_provider.dart';
import '../response_viewer/response_body_tab.dart' show rawResponseBody;
import 'request_draft_provider.dart';

/// Overridden in tests with a mocked [RequestExecutor]; the real app uses
/// the default `dio`-backed instance.
final requestExecutorProvider = Provider<RequestExecutor>((ref) => RequestExecutor());

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
    final executor = ref.read(requestExecutorProvider);
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
    }
  }
}

final sendStateProvider = NotifierProvider<SendNotifier, SendState>(SendNotifier.new);
