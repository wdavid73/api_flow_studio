import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/shell/environment_pill.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Real dart:io I/O (JsonStore) needs tester.runAsync().

void main() {
  Future<JsonStore> pumpPill(
    WidgetTester tester, {
    required List<Environment> environments,
    String? activeId,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('environment_pill_test_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final store = JsonStore(directory: tempDir);
    await store.writeEnvironments(environments);
    await store.writeActiveEnvironmentId(activeId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: Center(child: EnvironmentPill())),
        ),
      ),
    );
    await settle(tester);
    return store;
  }

  List<Environment> envs(List<String> names) =>
      [for (final n in names) Environment(id: n.toLowerCase(), name: n)];

  Color? fillOf(WidgetTester tester, String id) {
    final box = tester.widget<Container>(find.byKey(Key('env-pill-$id')));
    return (box.decoration as BoxDecoration?)?.color;
  }

  Color? labelColor(WidgetTester tester, String label) =>
      DefaultTextStyle.of(tester.element(find.text(label))).style.color;

  testWidgets('renders one button per environment, the active one in the accent', (tester) async {
    await tester.runAsync(() async {
      await pumpPill(tester, environments: envs(['Dev', 'QA', 'Staging']), activeId: 'qa');

      expect(find.byKey(const Key('environment-switcher')), findsOneWidget);
      expect(find.text('Dev'), findsOneWidget);
      expect(find.text('QA'), findsOneWidget);
      expect(find.text('Staging'), findsOneWidget);
      expect(fillOf(tester, 'qa'), AppColors.primary);
      expect(labelColor(tester, 'QA'), AppColors.onPrimary);
      expect(fillOf(tester, 'dev'), isNot(AppColors.primary));
    });
  });

  testWidgets('the active production environment is red', (tester) async {
    await tester.runAsync(() async {
      await pumpPill(tester, environments: envs(['Dev', 'Prod']), activeId: 'prod');

      expect(fillOf(tester, 'prod'), AppColors.error);
      expect(labelColor(tester, 'Prod'), AppColors.onError);
    });
  });

  testWidgets('tapping a button makes that environment active and persists it', (tester) async {
    await tester.runAsync(() async {
      final store = await pumpPill(tester, environments: envs(['Dev', 'QA']), activeId: 'dev');

      await tester.tap(find.text('QA'));
      await settle(tester);

      expect(fillOf(tester, 'qa'), AppColors.primary);
      expect(await store.readActiveEnvironmentId(), 'qa');
    });
  });

  testWidgets('with no environments nothing is drawn', (tester) async {
    await tester.runAsync(() async {
      await pumpPill(tester, environments: const []);

      expect(find.byKey(const Key('environment-switcher')), findsNothing);
    });
  });

  testWidgets('with 4 environments all four are buttons and there is no overflow menu', (tester) async {
    await tester.runAsync(() async {
      await pumpPill(tester, environments: envs(['A', 'B', 'C', 'D']), activeId: 'a');

      expect(find.byKey(const Key('environment-overflow')), findsNothing);
      expect(find.byKey(const Key('env-pill-d')), findsOneWidget);
    });
  });

  testWidgets('with 5 environments the extra ones go in the overflow menu', (tester) async {
    await tester.runAsync(() async {
      final store = await pumpPill(tester, environments: envs(['A', 'B', 'C', 'D', 'E']), activeId: 'a');

      expect(find.byKey(const Key('env-pill-c')), findsOneWidget);
      expect(find.byKey(const Key('env-pill-d')), findsNothing);
      expect(find.byKey(const Key('environment-overflow')), findsOneWidget);

      await tester.tap(find.byKey(const Key('environment-overflow')));
      await settle(tester);
      await tester.tap(find.text('E').last);
      await settle(tester);

      expect(await store.readActiveEnvironmentId(), 'e');
      expect(fillOf(tester, 'overflow'), AppColors.primary);
    });
  });
}

Future<void> settle(WidgetTester tester) async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
