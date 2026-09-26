import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/http/executed_response.dart';
import '../../engine/http/request_executor.dart';
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
    final response = await executor.execute(endpoint, variables: const {});
    state = SendState(response: response);
  }
}

final sendStateProvider = NotifierProvider<SendNotifier, SendState>(SendNotifier.new);
