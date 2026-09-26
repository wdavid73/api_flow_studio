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

  void setHeaders(List<KeyValueEntry> headers) => state = state.copyWith(headers: headers);

  void setQueryParams(List<KeyValueEntry> queryParams) =>
      state = state.copyWith(queryParams: queryParams);

  void setBody(RequestBody body) => state = state.copyWith(body: body);

  void setAuthConfig(AuthConfig authConfig) => state = state.copyWith(authConfig: authConfig);
}

final requestDraftProvider = NotifierProvider<RequestDraftNotifier, Endpoint>(
  RequestDraftNotifier.new,
);
