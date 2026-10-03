import 'dart:io';

import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/collections/sidebar_tree.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart' show jsonStoreProvider;
import 'package:api_flow_studio/ui/request_builder/request_bar.dart';
import 'package:api_flow_studio/ui/request_builder/send_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Real dart:io I/O (JsonStore) needs tester.runAsync(); see the note in
// tasks/plan.md.

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

void main() {
  setUpAll(() => registerFallbackValue(FakeEndpoint()));

  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
  }

  Future<JsonStore> pumpSidebar(WidgetTester tester) async {
    final tempDir = await Directory.systemTemp.createTemp('sidebar_tree_test_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final store = JsonStore(directory: tempDir);
    final executor = MockRequestExecutor();
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 200));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsonStoreProvider.overrideWithValue(store),
          requestExecutorProvider.overrideWithValue(executor),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(width: 280, child: SidebarTree()),
                Expanded(child: RequestBar()),
              ],
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    return store;
  }

  testWidgets('shows an empty-workspace state with no folders yet', (tester) async {
    await tester.runAsync(() async {
      await pumpSidebar(tester);

      expect(find.byKey(const Key('empty-workspace-state')), findsOneWidget);
    });
  });

  testWidgets('creating a folder, then a request inside it, loads it into the request builder',
      (tester) async {
    await tester.runAsync(() async {
      await pumpSidebar(tester);

      await tester.tap(find.byKey(const Key('new-root-folder-button')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('new-folder-name-field')), 'Authentication API');
      await tester.tap(find.byKey(const Key('confirm-new-folder-button')));
      await settle(tester);

      expect(find.text('Authentication API'), findsOneWidget);

      // Folders start collapsed -- expand it to reach the add-request button.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await settle(tester);

      await tester.tap(find.byTooltip('Add request'));
      await settle(tester);

      // The new endpoint shows up in the tree...
      expect(find.descendant(of: find.byType(SidebarTree), matching: find.text('New Request')), findsOneWidget);
      // ...and its name is the request builder's title...
      expect(find.byKey(const Key('request-header-title')), findsOneWidget);
      // ...and got loaded into the request builder draft (no longer the
      // blank sentinel, so Save is now enabled).
      expect(
        tester.widget<OutlinedButton>(find.byKey(const Key('save-request-button'))).onPressed,
        isNotNull,
      );
    });
  });

  testWidgets('the search field filters the tree to matching endpoints', (tester) async {
    await tester.runAsync(() async {
      final tempDir = await Directory.systemTemp.createTemp('sidebar_tree_test_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final store = JsonStore(directory: tempDir);
      final group = const Group(id: 'g-1', name: 'Authentication API');
      await store.writeCollections(groups: [group], endpoints: [
        const Endpoint(id: 'e-1', groupId: 'g-1', name: 'Login', method: 'POST', url: '/login'),
        const Endpoint(id: 'e-2', groupId: 'g-1', name: 'Logout', method: 'POST', url: '/logout'),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [jsonStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(home: Scaffold(body: SizedBox(width: 280, child: SidebarTree()))),
        ),
      );
      await settle(tester);

      // Expand the folder so its rows are in the tree. Assert via the
      // rows' own keys, not find.text() -- once we type into the search
      // field its own content can equal an endpoint's name too.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await settle(tester);
      expect(find.byKey(const Key('endpoint-row-e-1')), findsOneWidget);
      expect(find.byKey(const Key('endpoint-row-e-2')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('sidebar-search-field')), 'no-match-at-all');
      await settle(tester);
      expect(find.byKey(const Key('endpoint-row-e-1')), findsNothing);
      expect(find.byKey(const Key('endpoint-row-e-2')), findsNothing);

      await tester.enterText(find.byKey(const Key('sidebar-search-field')), 'Login');
      await settle(tester);
      expect(find.byKey(const Key('endpoint-row-e-1')), findsOneWidget);
      expect(find.byKey(const Key('endpoint-row-e-2')), findsNothing);
    });
  });

  testWidgets('clicking a saved endpoint loads it into the request builder draft',
      (tester) async {
    await tester.runAsync(() async {
      final tempDir = await Directory.systemTemp.createTemp('sidebar_tree_test_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final store = JsonStore(directory: tempDir);
      await store.writeCollections(
        groups: [const Group(id: 'g-1', name: 'Authentication API')],
        endpoints: [
          const Endpoint(
            id: 'e-1',
            groupId: 'g-1',
            name: 'Login',
            method: 'POST',
            url: '{{base_url}}/login',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [jsonStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  SizedBox(width: 280, child: SidebarTree()),
                  Expanded(child: RequestBar()),
                ],
              ),
            ),
          ),
        ),
      );
      await settle(tester);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await settle(tester);
      await tester.tap(find.byKey(const Key('endpoint-row-e-1')));
      await settle(tester);

      final urlField = tester.widget<TextField>(find.byKey(const Key('request-url-field')));
      expect(urlField.controller!.text, '{{base_url}}/login');
    });
  });

  testWidgets(
      'Save persists edits to an already-saved endpoint and survives a fresh provider read',
      (tester) async {
    await tester.runAsync(() async {
      final store = await pumpSidebar(tester);

      await tester.tap(find.byKey(const Key('new-root-folder-button')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('new-folder-name-field')), 'Folder');
      await tester.tap(find.byKey(const Key('confirm-new-folder-button')));
      await settle(tester);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await settle(tester);
      await tester.tap(find.byTooltip('Add request'));
      await settle(tester);

      await tester.enterText(find.byKey(const Key('request-url-field')), 'https://httpbin.org/get');
      await settle(tester);
      await tester.tap(find.byKey(const Key('save-request-button')));
      await settle(tester);

      final persisted = await store.readCollections();
      expect(persisted.endpoints.single.url, 'https://httpbin.org/get');
    });
  });

  testWidgets('deleting an endpoint removes it from the tree and persists', (tester) async {
    await tester.runAsync(() async {
      final tempDir = await Directory.systemTemp.createTemp('sidebar_tree_test_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final store = JsonStore(directory: tempDir);
      await store.writeCollections(
        groups: [const Group(id: 'g-1', name: 'Authentication API')],
        endpoints: [
          const Endpoint(id: 'e-1', groupId: 'g-1', name: 'Login', method: 'POST', url: '/login'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [jsonStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(home: Scaffold(body: SizedBox(width: 280, child: SidebarTree()))),
        ),
      );
      await settle(tester);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await settle(tester);
      expect(find.byKey(const Key('endpoint-row-e-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('delete-endpoint-e-1')));
      await settle(tester);

      expect(find.byKey(const Key('endpoint-row-e-1')), findsNothing);
      expect((await store.readCollections()).endpoints, isEmpty);
    });
  });

  testWidgets('deleting an empty folder removes it and persists', (tester) async {
    await tester.runAsync(() async {
      final tempDir = await Directory.systemTemp.createTemp('sidebar_tree_test_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final store = JsonStore(directory: tempDir);
      await store.writeCollections(
        groups: [const Group(id: 'g-1', name: 'Empty Folder')],
        endpoints: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [jsonStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(home: Scaffold(body: SizedBox(width: 280, child: SidebarTree()))),
        ),
      );
      await settle(tester);
      expect(find.text('Empty Folder'), findsOneWidget);

      await tester.tap(find.byKey(const Key('delete-group-g-1')));
      await settle(tester);

      expect(find.text('Empty Folder'), findsNothing);
      expect((await store.readCollections()).groups, isEmpty);
    });
  });

  testWidgets('deleting a non-empty folder is blocked with a warning, not silently dropped',
      (tester) async {
    await tester.runAsync(() async {
      final tempDir = await Directory.systemTemp.createTemp('sidebar_tree_test_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final store = JsonStore(directory: tempDir);
      await store.writeCollections(
        groups: [const Group(id: 'g-1', name: 'Authentication API')],
        endpoints: [
          const Endpoint(id: 'e-1', groupId: 'g-1', name: 'Login', method: 'POST', url: '/login'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [jsonStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(home: Scaffold(body: SizedBox(width: 280, child: SidebarTree()))),
        ),
      );
      await settle(tester);

      await tester.tap(find.byKey(const Key('delete-group-g-1')));
      await settle(tester);

      expect(find.text('Authentication API'), findsOneWidget);
      expect(find.textContaining('contents first'), findsOneWidget);
      expect((await store.readCollections()).groups, hasLength(1));
    });
  });
}
