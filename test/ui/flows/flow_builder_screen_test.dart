import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart' show jsonStoreProvider;
import 'package:api_flow_studio/ui/flows/flows_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Real dart:io I/O (JsonStore) needs tester.runAsync(); see tasks/plan.md.

void main() {
  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
  }

  Future<JsonStore> pumpScreen(WidgetTester tester) async {
    // Step cards (with the extract/assert/stop-on-failure editors) are taller
    // than the default 800x600 test surface can show 3 of at once; size the
    // surface like an actual desktop window so the pipeline list doesn't
    // need scrolling for these tests to find every step-card.
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tempDir = await Directory.systemTemp.createTemp('flow_builder_test_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final store = JsonStore(directory: tempDir);
    await store.writeCollections(
      groups: const [Group(id: 'g-1', name: 'Authentication API')],
      endpoints: const [
        Endpoint(id: 'e-1', groupId: 'g-1', name: 'Check user', method: 'GET', url: '/exists'),
        Endpoint(id: 'e-2', groupId: 'g-1', name: 'Send OTP', method: 'POST', url: '/otp'),
        Endpoint(id: 'e-3', groupId: 'g-1', name: 'Create user', method: 'POST', url: '/users'),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: Scaffold(body: FlowsScreen())),
      ),
    );
    await settle(tester);
    return store;
  }

  testWidgets('shows an empty state with no flows yet', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('empty-flows-state')), findsOneWidget);
      expect(find.byKey(const Key('no-flow-selected')), findsOneWidget);
    });
  });

  testWidgets('creating a flow shows its (empty) step pipeline state', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('new-flow-button')));
      await settle(tester);

      expect(find.byKey(const Key('empty-flow-state')), findsOneWidget);
    });
  });

  testWidgets('adding 3 steps from the picker builds the pipeline and persists', (tester) async {
    await tester.runAsync(() async {
      final store = await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('new-flow-button')));
      await settle(tester);

      for (final endpointId in ['add-step-picker-item-e-1', 'add-step-picker-item-e-2', 'add-step-picker-item-e-3']) {
        await tester.tap(find.byKey(const Key('add-step-button')));
        await settle(tester);
        await tester.tap(find.byKey(Key(endpointId)));
        await settle(tester);
      }

      expect(find.byKey(const Key('step-card-0')), findsOneWidget);
      expect(find.byKey(const Key('step-card-1')), findsOneWidget);
      expect(find.byKey(const Key('step-card-2')), findsOneWidget);
      expect(find.text('Check user'), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);
      expect(find.text('Create user'), findsOneWidget);

      final persisted = (await store.readFlows()).single;
      expect(persisted.steps.map((s) => s.endpointId), ['e-1', 'e-2', 'e-3']);
    });
  });

  testWidgets('removing a step drops it from the pipeline and persists', (tester) async {
    await tester.runAsync(() async {
      final store = await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('new-flow-button')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-step-button')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('add-step-picker-item-e-1')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('remove-step-0')));
      await settle(tester);

      expect(find.byKey(const Key('empty-flow-state')), findsOneWidget);
      expect((await store.readFlows()).single.steps, isEmpty);
    });
  });

  testWidgets('moving a step up reorders the pipeline and persists', (tester) async {
    await tester.runAsync(() async {
      final store = await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('new-flow-button')));
      await settle(tester);

      for (final endpointId in ['add-step-picker-item-e-1', 'add-step-picker-item-e-2']) {
        await tester.tap(find.byKey(const Key('add-step-button')));
        await settle(tester);
        await tester.tap(find.byKey(Key(endpointId)));
        await settle(tester);
      }

      // Move the second step ("Send OTP", index 1) up.
      await tester.tap(find.byKey(const Key('move-step-up-1')));
      await settle(tester);

      final steps = (await store.readFlows()).single.steps;
      expect(steps.map((s) => s.endpointId), ['e-2', 'e-1']);
    });
  });

  testWidgets('renaming a flow persists the new name', (tester) async {
    await tester.runAsync(() async {
      final store = await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('new-flow-button')));
      await settle(tester);

      await tester.enterText(find.byKey(const Key('flow-name-field')), 'User Registration Flow');
      await settle(tester);

      expect((await store.readFlows()).single.name, 'User Registration Flow');
    });
  });

  testWidgets('deleting the selected flow removes it, persists, and clears the builder',
      (tester) async {
    await tester.runAsync(() async {
      final store = await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('new-flow-button')));
      await settle(tester);

      final flowId = (await store.readFlows()).single.id;
      expect(find.byKey(const Key('empty-flow-state')), findsOneWidget);

      await tester.tap(find.byKey(Key('delete-flow-$flowId')));
      await settle(tester);

      expect(find.byKey(const Key('no-flow-selected')), findsOneWidget);
      expect(find.byKey(const Key('empty-flows-state')), findsOneWidget);
      expect(await store.readFlows(), isEmpty);
    });
  });
}
