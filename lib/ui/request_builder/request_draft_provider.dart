import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';

const draftEndpointId = 'draft';

/// The in-progress, unsaved request the user is editing in the request
/// builder. Purely in-memory Riverpod state -- persisting it as a saved
/// [Endpoint] into a collection is a later task (3.5).
class RequestDraftNotifier extends Notifier<Endpoint> {
  @override
  Endpoint build() => const Endpoint(
        id: draftEndpointId,
        groupId: '',
        name: 'Untitled Request',
        method: 'GET',
        url: '',
      );

  void setMethod(String method) => state = state.copyWith(method: method);

  void setUrl(String url) => state = state.copyWith(url: url);
}

final requestDraftProvider = NotifierProvider<RequestDraftNotifier, Endpoint>(
  RequestDraftNotifier.new,
);
