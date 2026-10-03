import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environment_manager_screen.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/shell/header_ghost_button.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpManager(
    WidgetTester tester, {
    required List<String> names,
    String? activeId,
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = JsonStore.inMemory();
    await store.writeEnvironments([for (final n in names) Environment(id: n.toLowerCase(), name: n)]);
    await store.writeActiveEnvironmentId(activeId);
    container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    await container.read(environmentsProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: EnvironmentManagerScreen())),
      ),
    );
    await tester.pump();
  }

  Finder activeTag(String id) => find.byKey(Key('env-active-tag-$id'));
  Finder prodTag(String id) => find.byKey(Key('env-prod-tag-$id'));
  Color dotColor(WidgetTester tester, String id) =>
      tester.widget<CircleAvatar>(find.byKey(Key('env-dot-$id'))).backgroundColor!;

  testWidgets('ACTIVE is shown only on the environment that is actually active', (tester) async {
    await pumpManager(tester, names: ['Dev', 'QA'], activeId: 'qa');
    // The editor is showing Dev (first), but QA is the active one.
    expect(activeTag('qa'), findsOneWidget);
    expect(activeTag('dev'), findsNothing);
  });

  testWidgets('selecting a row in the editor does not make it ACTIVE', (tester) async {
    await pumpManager(tester, names: ['Dev', 'QA'], activeId: 'dev');

    await tester.tap(find.byKey(const ValueKey('env-list-item-qa')));
    await tester.pump();

    expect(activeTag('dev'), findsOneWidget);
    expect(activeTag('qa'), findsNothing);
    expect(container.read(environmentsProvider).value!.activeEnvironmentId, 'dev');
  });

  testWidgets('with no active environment nothing says ACTIVE', (tester) async {
    await pumpManager(tester, names: ['Dev', 'QA']);

    expect(find.text('ACTIVE'), findsNothing);
  });

  testWidgets('a production environment gets a PROD tag and a red dot, others never do', (tester) async {
    await pumpManager(tester, names: ['Dev', 'Prod', 'QA', 'Staging']);

    expect(prodTag('prod'), findsOneWidget);
    expect(prodTag('dev'), findsNothing);
    expect(dotColor(tester, 'prod'), AppColors.error);
    for (final id in ['dev', 'qa', 'staging']) {
      expect(dotColor(tester, id), isNot(AppColors.error));
    }
  });

  testWidgets('non-production dots cycle primary, tertiary, secondary by position', (tester) async {
    await pumpManager(tester, names: ['Dev', 'Prod', 'QA', 'Staging']);

    expect(dotColor(tester, 'dev'), AppColors.primary);
    expect(dotColor(tester, 'qa'), AppColors.secondary);
    expect(dotColor(tester, 'staging'), AppColors.primary);
  });

  test('the dot palette contains no red', () {
    expect(AppColors.environmentDotPalette, isNot(contains(AppColors.error)));
    expect(AppColors.environmentDotPalette, [AppColors.primary, AppColors.tertiary, AppColors.secondary]);
  });

  group('list/detail restyle', () {
    testWidgets('the list panel is 300px with the ENVIRONMENTS kicker and a ghost New Environment button',
        (tester) async {
      await pumpManager(tester, names: ['Dev']);

      expect(tester.getSize(find.byKey(const Key('list-detail-list-panel'))).width, 300);
      expect(find.text('ENVIRONMENTS'), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('new-environment-button')), matching: find.text('New Environment')),
        findsOneWidget,
      );
      expect(find.byType(HeaderGhostButton), findsWidgets);
    });

    testWidgets('the selected row is surfaceContainerHigh and has no colored side bar', (tester) async {
      await pumpManager(tester, names: ['Dev', 'QA']);

      Color? fill(String id) => tester.widget<Material>(find.byKey(Key('env-row-surface-$id'))).color;

      expect(fill('dev'), AppColors.surfaceContainerHigh);
      expect(fill('qa'), Colors.transparent);
      final row = tester.widget<Container>(find.byKey(const Key('env-row-body-dev')));
      expect((row.decoration as BoxDecoration?)?.border, isNull);

      await tester.tap(find.byKey(const ValueKey('env-list-item-qa')));
      await tester.pump();

      expect(fill('qa'), AppColors.surfaceContainerHigh);
      expect(fill('dev'), Colors.transparent);
    });

    testWidgets('the editor titles the environment and labels its columns NAME, VALUE, SECRET', (tester) async {
      await pumpManager(tester, names: ['Dev']);
      await tester.tap(find.byKey(const Key('add-variable-button')));
      await tester.pump();
      await tester.pump();

      expect(tester.widget<Text>(find.byKey(const Key('env-editor-title'))).data, 'Dev');
      expect(find.text('NAME'), findsOneWidget);
      expect(find.text('VALUE'), findsOneWidget);
      expect(find.text('SECRET'), findsOneWidget);
      expect(find.text('VARIABLE NAME'), findsNothing);
    });

    testWidgets('Add variable is a ghost button', (tester) async {
      await pumpManager(tester, names: ['Dev']);

      expect(find.byKey(const Key('add-variable-button')), findsOneWidget);
      expect(tester.widget(find.byKey(const Key('add-variable-button'))), isA<HeaderGhostButton>());
    });
  });
}
