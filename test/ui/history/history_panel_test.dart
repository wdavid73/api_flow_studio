import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart' show jsonStoreProvider;
import 'package:api_flow_studio/ui/history/history_tab.dart';
import 'package:api_flow_studio/ui/request_builder/request_draft_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Real dart:io I/O (JsonStore) needs tester.runAsync(); see tasks/plan.md.
// history_wiring_test.dart already covers Send -> appendHistoryEntry
// end-to-end through RequestBar; these tests exercise HistoryTab's own
// rendering directly against a pre-populated store (what Send leaves
// behind), rather than fighting TabBarView's tab-switch animation timing
// inside the full RequestBar tree -- not what this task is actually about.

void main() {
  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
  }

  Future<JsonStore> makeStore() async {
    final tempDir = await Directory.systemTemp.createTemp('history_panel_test_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    return JsonStore(directory: tempDir);
  }

  const savedEndpoint = Endpoint(
    id: 'e-1',
    groupId: 'g-1',
    name: 'Get user',
    method: 'GET',
    url: 'https://api.dev/users/1',
  );

  testWidgets('shows the unsaved-draft state when the draft has no real endpoint id',
      (tester) async {
    await tester.runAsync(() async {
      final store = await makeStore();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [jsonStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(home: Scaffold(body: HistoryTab())),
        ),
      );
      await settle(tester);

      expect(find.byKey(const Key('history-unsaved-state')), findsOneWidget);
    });
  });

  testWidgets('shows an empty state for a saved endpoint that has never been sent',
      (tester) async {
    await tester.runAsync(() async {
      final store = await makeStore();
      final container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
      addTearDown(container.dispose);
      container.read(requestDraftProvider.notifier).loadEndpoint(savedEndpoint);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: HistoryTab())),
        ),
      );
      await settle(tester);

      expect(find.byKey(const Key('empty-history-state')), findsOneWidget);
    });
  });

  testWidgets('lists persisted entries most-recent-first', (tester) async {
    await tester.runAsync(() async {
      final store = await makeStore();
      await store.appendHistoryEntry(
        'e-1',
        HistoryEntry(id: 'h-1', endpointId: 'e-1', timestamp: DateTime(2026, 1, 1), status: 200, body: '{"call":1}'),
      );
      await store.appendHistoryEntry(
        'e-1',
        HistoryEntry(id: 'h-2', endpointId: 'e-1', timestamp: DateTime(2026, 1, 2), status: 500, body: '{"call":2}'),
      );

      final container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
      addTearDown(container.dispose);
      container.read(requestDraftProvider.notifier).loadEndpoint(savedEndpoint);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: HistoryTab())),
        ),
      );
      await settle(tester);

      expect(find.byKey(const Key('history-list')), findsOneWidget);
      final rows = find.byType(ExpansionTile);
      expect(rows, findsNWidgets(2));
      // Most-recent-first: h-2 (later timestamp) is the first row.
      expect(find.byKey(const Key('history-row-h-2')), findsOneWidget);
      final firstRowTop = tester.getTopLeft(find.byKey(const Key('history-row-h-2'))).dy;
      final secondRowTop = tester.getTopLeft(find.byKey(const Key('history-row-h-1'))).dy;
      expect(firstRowTop, lessThan(secondRowTop));
    });
  });

  testWidgets('expanding an entry shows its stored body, labeled historical', (tester) async {
    await tester.runAsync(() async {
      final store = await makeStore();
      await store.appendHistoryEntry(
        'e-1',
        HistoryEntry(
          id: 'h-1',
          endpointId: 'e-1',
          timestamp: DateTime(2026, 1, 1),
          status: 200,
          body: '{"user":"alice"}',
          elapsedMs: 42,
        ),
      );

      final container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
      addTearDown(container.dispose);
      container.read(requestDraftProvider.notifier).loadEndpoint(savedEndpoint);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: HistoryTab())),
        ),
      );
      await settle(tester);

      expect(find.byKey(const Key('historical-label')), findsNothing);
      await tester.tap(find.byKey(const Key('history-row-h-1')));
      await settle(tester);

      expect(find.byKey(const Key('historical-label')), findsOneWidget);
      expect(find.textContaining('"user"'), findsOneWidget);
      expect(find.textContaining('"alice"'), findsOneWidget);
    });
  });

  Future<void> pumpHistoryWith(WidgetTester tester, HistoryEntry entry) async {
    final store = await makeStore();
    await store.appendHistoryEntry('e-1', entry);
    final container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    container.read(requestDraftProvider.notifier).loadEndpoint(savedEndpoint);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: HistoryTab())),
      ),
    );
    await settle(tester);
  }

  testWidgets('an entry whose body was cut says so', (tester) async {
    await tester.runAsync(() async {
      await pumpHistoryWith(
        tester,
        HistoryEntry(id: 'h-1', endpointId: 'e-1', timestamp: DateTime(2026, 1, 1), status: 200, body: 'z' * (200 * 1024)),
      );

      await tester.tap(find.byKey(const Key('history-row-h-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('history-truncated-label')), findsOneWidget);
      expect(find.text('Body truncated to 100 KB'), findsOneWidget);
    });
  });

  testWidgets('an entry stored whole shows no truncation note', (tester) async {
    await tester.runAsync(() async {
      await pumpHistoryWith(
        tester,
        HistoryEntry(id: 'h-1', endpointId: 'e-1', timestamp: DateTime(2026, 1, 1), status: 200, body: '{"a":1}'),
      );

      await tester.tap(find.byKey(const Key('history-row-h-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const Key('historical-label')), findsOneWidget); // it did expand
      expect(find.byKey(const Key('history-truncated-label')), findsNothing);
    });
  });
}
