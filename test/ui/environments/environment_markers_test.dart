import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environment_manager_screen.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
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
}
