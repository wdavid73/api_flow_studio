import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/collections/sidebar_tree.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart' show jsonStoreProvider;
import 'package:api_flow_studio/ui/request_builder/request_draft_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Real dart:io I/O (JsonStore, via SidebarTree's collectionsProvider) needs
// tester.runAsync(); see tasks/plan.md.

void main() {
  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
  }

  Future<JsonStore> pumpSidebar(WidgetTester tester) async {
    final tempDir = await Directory.systemTemp.createTemp('paste_curl_dialog_test_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final store = JsonStore(directory: tempDir);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: Scaffold(body: SidebarTree())),
      ),
    );
    await settle(tester);
    return store;
  }

  testWidgets('pasting a valid curl command loads it into the request draft', (tester) async {
    await tester.runAsync(() async {
      await pumpSidebar(tester);

      await tester.tap(find.byKey(const Key('paste-curl-button')));
      await settle(tester);
      expect(find.byKey(const Key('paste-curl-field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('paste-curl-field')),
        "curl -X POST -H 'Content-Type: application/json' -d '{\"a\":1}' https://api.example.com/users",
      );
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirm-paste-curl-button')));
      await settle(tester);

      expect(find.byKey(const Key('paste-curl-field')), findsNothing);

      final container = ProviderScope.containerOf(tester.element(find.byType(SidebarTree)));
      final draft = container.read(requestDraftProvider);
      expect(draft.id, draftEndpointId);
      expect(draft.method, 'POST');
      expect(draft.url, 'https://api.example.com/users');
      expect(draft.headers, [const KeyValueEntry(key: 'Content-Type', value: 'application/json')]);
      expect(draft.body, const RequestBody.json('{"a":1}'));
    });
  });

  testWidgets('a parse failure shows an inline error and keeps the dialog open to retry',
      (tester) async {
    await tester.runAsync(() async {
      await pumpSidebar(tester);

      await tester.tap(find.byKey(const Key('paste-curl-button')));
      await settle(tester);

      await tester.enterText(find.byKey(const Key('paste-curl-field')), 'curl -X POST');
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirm-paste-curl-button')));
      await settle(tester);

      expect(find.byKey(const Key('paste-curl-error')), findsOneWidget);
      expect(find.byKey(const Key('paste-curl-field')), findsOneWidget);

      // The user can now edit and retry without reopening the dialog.
      await tester.enterText(
        find.byKey(const Key('paste-curl-field')),
        'curl https://api.example.com/health',
      );
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirm-paste-curl-button')));
      await settle(tester);

      expect(find.byKey(const Key('paste-curl-field')), findsNothing);
      final container = ProviderScope.containerOf(tester.element(find.byType(SidebarTree)));
      expect(container.read(requestDraftProvider).url, 'https://api.example.com/health');
    });
  });

  testWidgets('cancel closes the dialog without changing the draft', (tester) async {
    await tester.runAsync(() async {
      await pumpSidebar(tester);
      final container = ProviderScope.containerOf(tester.element(find.byType(SidebarTree)));
      final before = container.read(requestDraftProvider);

      await tester.tap(find.byKey(const Key('paste-curl-button')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('cancel-paste-curl-button')));
      await settle(tester);

      expect(find.byKey(const Key('paste-curl-field')), findsNothing);
      expect(container.read(requestDraftProvider), before);
    });
  });
}
