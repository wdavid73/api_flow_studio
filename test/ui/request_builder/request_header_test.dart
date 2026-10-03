import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/collections/collections_provider.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/request_builder/request_draft_provider.dart';
import 'package:api_flow_studio/ui/request_builder/request_header.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpHeader(WidgetTester tester) async {
    final store = JsonStore.inMemory();
    await store.writeCollections(
      groups: const [Group(id: 'g-1', name: 'Auth')],
      endpoints: const [],
    );
    container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    await container.read(collectionsProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: RequestHeader())),
      ),
    );
  }

  String textOf(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

  testWidgets('an unsaved draft shows UNSAVED and the default title', (tester) async {
    await pumpHeader(tester);

    expect(textOf(tester, 'request-header-kicker'), 'UNSAVED');
    expect(textOf(tester, 'request-header-title'), 'Untitled Request');
    expect(find.byKey(const Key('request-header-description')), findsNothing);
  });

  testWidgets('a saved endpoint shows its folder, name and first description line', (tester) async {
    await pumpHeader(tester);

    container.read(requestDraftProvider.notifier).loadEndpoint(const Endpoint(
          id: 'e-1',
          groupId: 'g-1',
          name: 'Sign in',
          method: 'POST',
          url: 'https://x.test/auth',
          description: 'Logs a customer in.\nSecond line is not shown.',
        ));
    await tester.pump();

    expect(textOf(tester, 'request-header-kicker'), 'AUTH');
    expect(textOf(tester, 'request-header-title'), 'Sign in');
    expect(textOf(tester, 'request-header-description'), 'Logs a customer in.');
  });

  testWidgets('an endpoint whose folder is gone still renders, with a placeholder kicker', (tester) async {
    await pumpHeader(tester);

    container.read(requestDraftProvider.notifier).loadEndpoint(const Endpoint(
          id: 'e-2',
          groupId: 'missing',
          name: 'Orphan',
          method: 'GET',
          url: '/x',
        ));
    await tester.pump();

    expect(textOf(tester, 'request-header-kicker'), 'NO FOLDER');
    expect(textOf(tester, 'request-header-title'), 'Orphan');
  });
}
