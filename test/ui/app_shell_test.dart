import 'dart:io';

import 'package:api_flow_studio/app.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Real dart:io calls (JsonStore, via environmentsProvider -- now watched by
// ActiveEnvironmentStrip/EnvironmentSwitcher regardless of which nav
// destination is showing) need tester.runAsync(); see the note in
// tasks/plan.md and environment_manager_screen_test.dart.

void main() {
  Future<void> pumpDesktopApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tempDir = await Directory.systemTemp.createTemp('app_shell_test_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final store = JsonStore(directory: tempDir);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonStoreProvider.overrideWithValue(store)],
        child: const ApiFlowStudioApp(),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }

  testWidgets('renders all 4 nav destinations', (tester) async {
    await tester.runAsync(() async {
      await pumpDesktopApp(tester);

      expect(find.text('Workspace'), findsOneWidget);
      expect(find.text('Environments'), findsOneWidget);
      expect(find.text('Flows'), findsOneWidget);
      // "History" also labels a tab inside the Workspace's request
      // builder (Task 4.3) -- at least one match (the nav item) is enough
      // here; the request-builder tab's own presence is covered elsewhere.
      expect(find.text('History'), findsWidgets);
    });
  });

  testWidgets('starts on the Workspace destination showing the request builder', (tester) async {
    await tester.runAsync(() async {
      await pumpDesktopApp(tester);

      expect(find.byKey(const Key('request-url-field')), findsOneWidget);
    });
  });

  testWidgets('tapping a nav destination switches the visible body', (tester) async {
    await tester.runAsync(() async {
      await pumpDesktopApp(tester);

      await tester.tap(find.text('Environments'));
      await tester.pump();

      expect(find.byKey(const Key('empty-environments-state')), findsOneWidget);
      expect(find.byKey(const Key('request-url-field')), findsNothing);
    });
  });
}
