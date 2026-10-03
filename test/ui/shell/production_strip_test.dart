import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/shell/production_strip.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Real dart:io I/O (JsonStore) needs tester.runAsync().

void main() {
  Future<void> pumpStrip(
    WidgetTester tester, {
    required List<Environment> environments,
    String? activeId,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('production_strip_test_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final store = JsonStore(directory: tempDir);
    await store.writeEnvironments(environments);
    await store.writeActiveEnvironmentId(activeId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: Scaffold(body: Column(children: [ProductionStrip()]))),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
  }

  Container strip(WidgetTester tester) =>
      tester.widget<Container>(find.byKey(const Key('active-environment-strip')));

  testWidgets('is a 3px error-colored bar when the active environment is prod', (tester) async {
    await tester.runAsync(() async {
      await pumpStrip(
        tester,
        environments: [Environment(id: 'dev', name: 'Dev'), Environment(id: 'prod', name: 'Prod')],
        activeId: 'prod',
      );

      expect(tester.getSize(find.byKey(const Key('active-environment-strip'))).height, 3);
      expect(strip(tester).color, AppColors.error);
    });
  });

  testWidgets('has no height when a non-prod environment is active', (tester) async {
    await tester.runAsync(() async {
      await pumpStrip(
        tester,
        environments: [Environment(id: 'dev', name: 'Dev'), Environment(id: 'prod', name: 'Prod')],
        activeId: 'dev',
      );

      expect(tester.getSize(find.byKey(const Key('active-environment-strip'))).height, 0);
    });
  });

  testWidgets('has no height with no environments at all', (tester) async {
    await tester.runAsync(() async {
      await pumpStrip(tester, environments: const []);

      expect(tester.getSize(find.byKey(const Key('active-environment-strip'))).height, 0);
    });
  });
}
