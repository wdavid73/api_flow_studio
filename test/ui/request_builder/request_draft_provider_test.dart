import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/ui/request_builder/request_draft_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  test('starts as an empty untitled GET draft', () {
    final draft = container.read(requestDraftProvider);

    expect(draft.method, 'GET');
    expect(draft.url, '');
    expect(draft.headers, isEmpty);
  });

  test('setHeaders replaces the draft headers', () {
    const headers = [KeyValueEntry(key: 'Content-Type', value: 'application/json')];

    container.read(requestDraftProvider.notifier).setHeaders(headers);

    expect(container.read(requestDraftProvider).headers, headers);
  });

  test('setQueryParams replaces the draft query params', () {
    const params = [KeyValueEntry(key: 'debug', value: 'true')];

    container.read(requestDraftProvider.notifier).setQueryParams(params);

    expect(container.read(requestDraftProvider).queryParams, params);
  });

  test('setBody replaces the draft body', () {
    const body = RequestBody.json('{"a":1}');

    container.read(requestDraftProvider.notifier).setBody(body);

    expect(container.read(requestDraftProvider).body, body);
  });

  test('setAuthConfig replaces the draft auth', () {
    const auth = AuthConfig.bearer(token: '{{auth_token}}');

    container.read(requestDraftProvider.notifier).setAuthConfig(auth);

    expect(container.read(requestDraftProvider).authConfig, auth);
  });

  group('switchBodyKind', () {
    test('brings back what was typed under a body type after visiting another one', () {
      final notifier = container.read(requestDraftProvider.notifier);
      notifier.setBody(const RequestBody.json('{"a":1}'));

      notifier.switchBodyKind(const RequestBody.formUrlEncoded([]));
      expect(container.read(requestDraftProvider).body, const RequestBody.formUrlEncoded([]));
      notifier.setBody(const RequestBody.formUrlEncoded([KeyValueEntry(key: 'k', value: 'v')]));

      notifier.switchBodyKind(const RequestBody.json(''));
      expect(container.read(requestDraftProvider).body, const RequestBody.json('{"a":1}'));

      notifier.switchBodyKind(const RequestBody.formUrlEncoded([]));
      expect(
        container.read(requestDraftProvider).body,
        const RequestBody.formUrlEncoded([KeyValueEntry(key: 'k', value: 'v')]),
      );
    });

    test('forgets the stash when another request is loaded', () {
      final notifier = container.read(requestDraftProvider.notifier);
      notifier.setBody(const RequestBody.json('{"a":1}'));
      notifier.switchBodyKind(const RequestBody.none());

      notifier.loadEndpoint(const Endpoint(id: 'e-9', groupId: 'g', name: 'Other', method: 'GET', url: '/'));
      notifier.switchBodyKind(const RequestBody.json(''));

      expect(container.read(requestDraftProvider).body, const RequestBody.json(''));
    });
  });
}
