import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/shell/app_destination.dart';
import 'package:api_flow_studio/ui/shell/app_header.dart';
import 'package:api_flow_studio/ui/shell/environment_pill.dart';
import 'package:api_flow_studio/ui/shell/header_ghost_button.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:api_flow_studio/ui/theme/widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Real dart:io I/O (JsonStore) needs tester.runAsync().

void main() {
  Future<ProviderContainer> pumpHeader(
    WidgetTester tester, {
    double width = 1440,
    List<Widget> actions = const [],
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tempDir = await Directory.systemTemp.createTemp('app_header_test_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final store = JsonStore(directory: tempDir);
    await store.writeEnvironments([Environment(id: 'dev', name: 'Dev')]);
    await store.writeActiveEnvironmentId('dev');

    final container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: Column(children: [AppHeader(actions: actions)])),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
    return container;
  }

  testWidgets('shows the brand, subtitle, four destinations and the environment pill', (tester) async {
    await tester.runAsync(() async {
      await pumpHeader(tester);

      expect(find.byType(AppLogoMark), findsOneWidget);
      expect(find.text('API Flow Studio'), findsOneWidget);
      expect(find.text('API playground'), findsOneWidget);
      for (final label in ['Workspace', 'Environments', 'Flows', 'History']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.byType(EnvironmentPill), findsOneWidget);
    });
  });

  testWidgets('the selected destination is highlighted and tapping another selects it', (tester) async {
    await tester.runAsync(() async {
      final container = await pumpHeader(tester);

      Color? fillOf(String label) {
        final item = find.ancestor(of: find.text(label), matching: find.byType(Container)).first;
        return (tester.widget<Container>(item).decoration as BoxDecoration?)?.color;
      }

      expect(fillOf('Workspace'), AppColors.surfaceContainerHigh);
      expect(fillOf('Flows'), isNull);

      await tester.tap(find.text('Flows'));
      await tester.pump();

      expect(container.read(selectedDestinationProvider), AppDestination.flows);
      expect(fillOf('Flows'), AppColors.surfaceContainerHigh);
      expect(fillOf('Workspace'), isNull);
    });
  });

  testWidgets('puts supplied actions in the right-hand zone', (tester) async {
    await tester.runAsync(() async {
      var pressed = 0;
      await pumpHeader(
        tester,
        actions: [HeaderGhostButton(label: 'Hosts y notas', onPressed: () => pressed++)],
      );

      await tester.tap(find.text('Hosts y notas'));

      expect(pressed, 1);
      expect(
        tester.getTopRight(find.text('Hosts y notas')).dx,
        greaterThan(tester.getTopRight(find.byType(EnvironmentPill)).dx),
      );
    });
  });

  testWidgets('is a single 56px row on a wide window', (tester) async {
    await tester.runAsync(() async {
      await pumpHeader(tester, width: 1440);

      expect(tester.getSize(find.byType(AppHeader)).height, 56);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('wraps onto more lines on a narrow window without overflowing', (tester) async {
    await tester.runAsync(() async {
      await pumpHeader(
        tester,
        width: 700,
        actions: [HeaderGhostButton(label: 'Hosts y notas', onPressed: () {})],
      );

      expect(tester.getSize(find.byType(AppHeader)).height, greaterThan(56));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('HeaderGhostButton has an outlineVariant border and 10px radius', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: HeaderGhostButton(label: 'Sesion', onPressed: () {})),
      ),
    );

    final box = tester.widget<Container>(
      find.descendant(of: find.byType(HeaderGhostButton), matching: find.byType(Container)).first,
    );
    final decoration = box.decoration! as BoxDecoration;

    expect(decoration.border, Border.all(color: AppColors.outlineVariant));
    expect(decoration.borderRadius, BorderRadius.circular(10));
  });
}
