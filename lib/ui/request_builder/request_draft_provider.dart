import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../projects/projects_provider.dart';

const draftEndpointId = 'draft';

/// The in-progress, unsaved request the user is editing in the request
/// builder. Purely in-memory Riverpod state -- persisting it as a saved
/// [Endpoint] into a collection is a later task (3.5).
class RequestDraftNotifier extends Notifier<Endpoint> {
  @override
  Endpoint build() {
    ref.watch(activeProjectIdProvider); // the draft belongs to one project
    return _blank;
  }

  static const _blank = Endpoint(
        id: draftEndpointId,
        groupId: '',
        name: 'Untitled Request',
        method: 'GET',
        url: '',
      );

  void setMethod(String method) => state = state.copyWith(method: method);

  void setUrl(String url) => state = state.copyWith(url: url);

  void setDescription(String description) => state = state.copyWith(description: description);

  void setHeaders(List<KeyValueEntry> headers) => state = state.copyWith(headers: headers);

  void setQueryParams(List<KeyValueEntry> queryParams) =>
      state = state.copyWith(queryParams: queryParams);

  void setName(String name) => state = state.copyWith(name: name);

  void setBody(RequestBody body) => state = state.copyWith(body: body);

  /// What was typed under each body type of this request, so going JSON ->
  /// form -> JSON brings the JSON back instead of an empty editor. Memory only,
  /// and forgotten when another request is loaded.
  final Map<String, RequestBody> _bodyByKind = {};

  static String _kindOf(RequestBody body) => body.map(
        none: (_) => 'none',
        json: (_) => 'json',
        formUrlEncoded: (_) => 'form',
        multipart: (_) => 'multipart',
      );

  /// Switches the body to the type [kind] names, restoring what it held last
  /// time or starting from [empty].
  void switchBodyKind(RequestBody empty) {
    _bodyByKind[_kindOf(state.body)] = state.body;
    state = state.copyWith(body: _bodyByKind[_kindOf(empty)] ?? empty);
  }

  void setAuthConfig(AuthConfig authConfig) => state = state.copyWith(authConfig: authConfig);

  /// Replaces the whole draft with a saved [Endpoint] -- clicking a
  /// sidebar row loads it wholesale, discarding whatever was being edited
  /// (no unsaved-changes warning in v1, per SPEC).
  void loadEndpoint(Endpoint endpoint) {
    _bodyByKind.clear();
    state = endpoint;
  }

  /// Resets to a blank, unsaved draft (still `draftEndpointId`).
  void reset() {
    _bodyByKind.clear();
    state = _blank;
  }
}

final requestDraftProvider = NotifierProvider<RequestDraftNotifier, Endpoint>(
  RequestDraftNotifier.new,
);
