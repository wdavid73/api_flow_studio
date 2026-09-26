import 'dart:io';

import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environment_manager_screen.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// NOTE: every real dart:io call in this file (Directory.createTemp, and
// anything JsonStore does under the hood) has to happen inside
// tester.runAsync() -- testWidgets() runs its body in a synchronous/
// fake-time zone by default, where a real Future from actual file I/O
// never completes. The plain, non-widget tests in json_store_test.dart and
// environments_provider_test.dart don't need this because test() (not
// testWidgets()) runs in a normal zone.
//
// pumpAndSettle() also doesn't reliably detect settling here (it still
// times out waiting on the AsyncNotifier's loading -> data transition even
// though the real I/O behind it resolves in milliseconds) -- use a short
// real delay plus a couple of plain pump()s instead.

Future<void> settle(WidgetTester tester) async {
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await tester.pump();
  await tester.pump();
}

void main() {
  Future<JsonStore> pumpScreen(WidgetTester tester) async {
    final tempDir = await Directory.systemTemp.createTemp('env_screen_test_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final store = JsonStore(directory: tempDir);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: Scaffold(body: EnvironmentManagerScreen())),
      ),
    );
    await settle(tester);
    return store;
  }

  testWidgets('shows an empty state with no environments', (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('empty-environments-state')), findsOneWidget);
      expect(find.byKey(const Key('no-environment-selected')), findsOneWidget);
    });
  });

  testWidgets('creating an environment selects it and shows its (empty) variable editor',
      (tester) async {
    await tester.runAsync(() async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('new-environment-button')));
      await settle(tester);

      expect(find.text('New Environment'), findsWidgets);
      expect(find.byKey(const Key('no-environment-selected')), findsNothing);
    });
  });

  testWidgets('add variable, edit its value, and toggle secret persist to disk', (tester) async {
    await tester.runAsync(() async {
      final store = await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('new-environment-button')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('add-variable-button')));
      await settle(tester);
      // Each field edit gets its own settle, same as a real user moving
      // focus between fields one at a time (not all three simultaneously
      // within a single synchronous batch, which even a fast typist can't
      // actually do -- Flutter dispatches each field's change on its own).
      await tester.enterText(find.byKey(const Key('variable-name-field')), 'base_url');
      await settle(tester);
      await tester.enterText(find.byKey(const Key('variable-value-field')), 'https://api.dev');
      await settle(tester);
      await tester.tap(find.byKey(const Key('variable-secret-checkbox')));
      await settle(tester);

      final persisted = await store.readEnvironments();
      final variable = persisted.single.variables['base_url'];
      expect(variable?.value, 'https://api.dev');
      expect(variable?.secret, isTrue);
    });
  });

  testWidgets('renaming a variable keeps the other variables intact', (tester) async {
    await tester.runAsync(() async {
      final store = await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('new-environment-button')));
      await settle(tester);

      await tester.tap(find.byKey(const Key('add-variable-button')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('variable-name-field')), 'first');
      await settle(tester);

      await tester.tap(find.byKey(const Key('add-variable-button')));
      await settle(tester);
      final nameFields = find.byKey(const Key('variable-name-field'));
      await tester.enterText(nameFields.last, 'second');
      await settle(tester);

      // Rename the first row.
      await tester.enterText(nameFields.first, 'renamed_first');
      await settle(tester);

      final persisted = (await store.readEnvironments()).single.variables;
      expect(persisted.keys, containsAll(['renamed_first', 'second']));
      expect(persisted.containsKey('first'), isFalse);
    });
  });

  testWidgets('deleting an environment removes it from the list', (tester) async {
    await tester.runAsync(() async {
      final store = await pumpScreen(tester);
      await tester.tap(find.byKey(const Key('new-environment-button')));
      await settle(tester);

      final env = (await store.readEnvironments()).single;
      await tester.tap(find.byKey(ValueKey('delete-env-button-${env.id}')));
      await settle(tester);

      expect(find.byKey(const Key('empty-environments-state')), findsOneWidget);
      expect(await store.readEnvironments(), isEmpty);
    });
  });
}
