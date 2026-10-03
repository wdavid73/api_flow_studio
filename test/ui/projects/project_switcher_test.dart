import 'package:api_flow_studio/engine/projects/project.dart';
import 'package:api_flow_studio/engine/projects/projects_repository.dart';
import 'package:api_flow_studio/ui/projects/project_colors.dart';
import 'package:api_flow_studio/ui/projects/project_switcher.dart';
import 'package:api_flow_studio/ui/projects/projects_provider.dart';
import 'package:api_flow_studio/ui/shell/app_header.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProjectsRepository repo;
  late Project work;
  late Project personal;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {Widget? child, double width = 1400, bool withRepository = true}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    repo = ProjectsRepository.inMemory();
    work = await repo.create('commodo', colorIndex: 0);
    personal = await repo.create('fin_track_pro', colorIndex: 2);
    final state = await ProjectsController.load(repo);
    container = ProviderContainer(overrides: [
      if (withRepository) projectsRepositoryProvider.overrideWithValue(repo),
      if (withRepository) initialProjectsStateProvider.overrideWithValue(state),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(body: child ?? const Align(alignment: Alignment.topLeft, child: ProjectSwitcher())),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('project-switcher')));
    await tester.pumpAndSettle();
  }

  group('the button', () {
    testWidgets('shows the active project name and its color', (tester) async {
      await pump(tester);

      expect(find.descendant(of: find.byKey(const Key('project-switcher')), matching: find.text('commodo')), findsOneWidget);
      final dot = tester.widget<Container>(find.byKey(const Key('project-switcher-dot')));
      expect((dot.decoration! as BoxDecoration).color, projectColor(0));
    });

    testWidgets('a project with another color shows that one', (tester) async {
      await pump(tester);
      await container.read(projectsProvider.notifier).switchTo(personal.id);
      await tester.pump();

      expect(find.descendant(of: find.byKey(const Key('project-switcher')), matching: find.text('fin_track_pro')), findsOneWidget);
      final dot = tester.widget<Container>(find.byKey(const Key('project-switcher-dot')));
      expect((dot.decoration! as BoxDecoration).color, projectColor(2));
    });

    testWidgets('a very long name is cut instead of overflowing', (tester) async {
      await pump(tester);
      await container.read(projectsProvider.notifier).rename(work.id, 'WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW');
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const Key('project-switcher'))).width, lessThan(260));
    });
  });

  group('colors', () {
    test('every index maps to a color and the palette wraps around', () {
      expect(projectColor(0), projectColors.first);
      expect(projectColor(projectColors.length), projectColors.first);
      expect(projectColor(-1), projectColors.last);
      expect(projectColors.toSet(), hasLength(projectColors.length));
    });
  });

  group('the menu', () {
    testWidgets('lists every project and marks the active one', (tester) async {
      await pump(tester);

      await openMenu(tester);

      expect(find.byKey(Key('project-option-${work.id}')), findsOneWidget);
      expect(find.byKey(Key('project-option-${personal.id}')), findsOneWidget);
      expect(find.descendant(of: find.byKey(Key('project-option-${work.id}')), matching: find.byIcon(Icons.check)), findsOneWidget);
      expect(find.descendant(of: find.byKey(Key('project-option-${personal.id}')), matching: find.byIcon(Icons.check)), findsNothing);
    });

    testWidgets('choosing another project makes it the active one', (tester) async {
      await pump(tester);
      await openMenu(tester);

      await tester.tap(find.byKey(Key('project-option-${personal.id}')));
      await tester.pumpAndSettle();

      expect(container.read(projectsProvider).active.id, personal.id);
      expect(find.descendant(of: find.byKey(const Key('project-switcher')), matching: find.text('fin_track_pro')), findsOneWidget);
      expect((await repo.activeProject())!.id, personal.id);
    });

    testWidgets('choosing the active one again changes nothing and does not fail', (tester) async {
      await pump(tester);
      await openMenu(tester);

      await tester.tap(find.byKey(Key('project-option-${work.id}')));
      await tester.pumpAndSettle();

      expect(container.read(projectsProvider).active.id, work.id);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without projects configured it shows the single Default project', (tester) async {
      await pump(tester, withRepository: false);

      expect(find.descendant(of: find.byKey(const Key('project-switcher')), matching: find.text('Default')), findsOneWidget);
      await openMenu(tester);
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('in the header', () {
    testWidgets('it sits next to the brand on a wide window', (tester) async {
      await pump(tester, child: const AppHeader());

      expect(find.descendant(of: find.byType(AppHeader), matching: find.byKey(const Key('project-switcher'))), findsOneWidget);
      final brand = tester.getTopLeft(find.text('API Flow Studio'));
      final switcher = tester.getTopLeft(find.byKey(const Key('project-switcher')));
      expect(switcher.dx, greaterThan(brand.dx));
      expect(tester.takeException(), isNull);
    });

    testWidgets('it still fits when the header wraps on a narrow window', (tester) async {
      await pump(tester, child: const AppHeader(), width: 700);

      expect(find.byKey(const Key('project-switcher')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
