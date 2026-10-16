import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/collections/collections_provider.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/request_builder/request_draft_provider.dart';
import 'package:api_flow_studio/ui/request_builder/request_header.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  group('renaming', () {
    const saved = Endpoint(id: 'e-1', groupId: 'g-1', name: 'Sign in', method: 'POST', url: '/auth');

    testWidgets('clicking the title turns it into an input; Enter saves the new name', (tester) async {
      await pumpHeader(tester);
      await container.read(collectionsProvider.notifier).createEndpoint(saved);
      container.read(requestDraftProvider.notifier).loadEndpoint(saved);
      await tester.pump();

      await tester.tap(find.byKey(const Key('request-header-title')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('request-header-title-field')), 'Log in');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.byKey(const Key('request-header-title-field')), findsNothing);
      expect(textOf(tester, 'request-header-title'), 'Log in');
      expect(container.read(requestDraftProvider).name, 'Log in');
      // A saved request is renamed in the collections too (the sidebar shows it).
      expect(container.read(collectionsProvider).value!.endpoints.single.name, 'Log in');
    });

    testWidgets('an unsaved draft is renamed in the draft only', (tester) async {
      await pumpHeader(tester);

      await tester.tap(find.byKey(const Key('request-header-title')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('request-header-title-field')), 'Pasted call');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(container.read(requestDraftProvider).name, 'Pasted call');
      expect(container.read(collectionsProvider).value!.endpoints, isEmpty);
    });

    testWidgets('Escape cancels and an empty name is ignored', (tester) async {
      await pumpHeader(tester);

      await tester.tap(find.byKey(const Key('request-header-title')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('request-header-title-field')), 'Discarded');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(textOf(tester, 'request-header-title'), 'Untitled Request');

      await tester.tap(find.byKey(const Key('request-header-title')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('request-header-title-field')), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(textOf(tester, 'request-header-title'), 'Untitled Request');
    });
  });
}
