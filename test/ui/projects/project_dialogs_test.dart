import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/projects/project.dart';
import 'package:api_flow_studio/engine/projects/projects_repository.dart';
import 'package:api_flow_studio/ui/projects/project_switcher.dart';
import 'package:api_flow_studio/ui/projects/projects_provider.dart';
import 'package:api_flow_studio/ui/shell/app_toast.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A widget test that lets the toast's timer run out before it ends, so no
/// timer is left pending.
void projectTest(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pump(toastDuration + const Duration(milliseconds: 1));
  });
}

void main() {
  late ProjectsRepository repo;
  late Project work;
  late Project personal;
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, {bool single = false}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    repo = ProjectsRepository.inMemory();
    work = await repo.create('commodo', colorIndex: 0);
    if (!single) personal = await repo.create('fin_track_pro', colorIndex: 2);
    await (await repo.storeFor(work.id)).writeFlows([const Flow(id: 'f1', name: 'Kept')]);
    final state = await ProjectsController.load(repo);
    container = ProviderContainer(overrides: [
      projectsRepositoryProvider.overrideWithValue(repo),
      initialProjectsStateProvider.overrideWithValue(state),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(body: Align(alignment: Alignment.topLeft, child: ProjectSwitcher())),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('project-switcher')));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String key) async {
    await openMenu(tester);
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  Future<void> typeName(WidgetTester tester, String name) async {
    await tester.enterText(find.byKey(const Key('project-name-field')), name);
    await tester.pump();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('project-dialog-confirm-button')));
    await tester.pumpAndSettle();
  }

  String? errorText(WidgetTester tester) {
    final error = find.byKey(const Key('project-name-error'));
    return error.evaluate().isEmpty ? null : tester.widget<Text>(error).data;
  }

  group('menu actions', () {
    projectTest('New, Rename and Delete are offered after the projects', (tester) async {
      await pump(tester);

      await openMenu(tester);

      expect(find.byKey(const Key('new-project-button')), findsOneWidget);
      expect(find.byKey(const Key('rename-project-button')), findsOneWidget);
      expect(find.byKey(const Key('delete-project-button')), findsOneWidget);
    });

    projectTest('Delete is not offered when only one project is left', (tester) async {
      await pump(tester, single: true);

      await openMenu(tester);

      expect(find.byKey(const Key('new-project-button')), findsOneWidget);
      expect(find.byKey(const Key('rename-project-button')), findsOneWidget);
      expect(find.byKey(const Key('delete-project-button')), findsNothing);
    });
  });

  group('new project', () {
    projectTest('creates an empty project, makes it the active one and says so', (tester) async {
      await pump(tester);
      await choose(tester, 'new-project-button');

      await typeName(tester, '  side_project ');
      await confirm(tester);

      final state = container.read(projectsProvider);
      expect(state.active.name, 'side_project');
      expect(state.projects, hasLength(3));
      expect(await state.store.readFlows(), isEmpty);
      expect(find.byKey(const Key('project-name-field')), findsNothing);
      expect(container.read(toastProvider), 'Project "side_project" created');
    });

    projectTest('the chosen color is saved with the project', (tester) async {
      await pump(tester);
      await choose(tester, 'new-project-button');

      await typeName(tester, 'blue one');
      await tester.tap(find.byKey(const Key('project-color-3')));
      await tester.pump();
      await confirm(tester);

      expect(container.read(projectsProvider).active.colorIndex, 3);
    });

    projectTest('a project gets a different default color than the one before', (tester) async {
      await pump(tester);
      await choose(tester, 'new-project-button');

      await typeName(tester, 'default color');
      await confirm(tester);

      // Two projects already exist (colors 0 and 2): the next unused index is 1.
      expect(container.read(projectsProvider).active.colorIndex, 1);
    });

    projectTest('an empty name shows an error and keeps the dialog open', (tester) async {
      await pump(tester);
      await choose(tester, 'new-project-button');

      await confirm(tester);

      expect(errorText(tester), 'Give the project a name.');
      expect(find.byKey(const Key('project-name-field')), findsOneWidget);
      expect(container.read(projectsProvider).projects, hasLength(2));
    });

    projectTest('a repeated name shows an error whatever its casing', (tester) async {
      await pump(tester);
      await choose(tester, 'new-project-button');

      await typeName(tester, 'COMMODO');
      await confirm(tester);

      expect(errorText(tester), 'A project with that name already exists.');
      expect(container.read(projectsProvider).projects, hasLength(2));
    });

    projectTest('a name over 40 characters shows an error; the error clears as it is fixed', (tester) async {
      await pump(tester);
      await choose(tester, 'new-project-button');

      await typeName(tester, 'x' * 41);
      await confirm(tester);
      expect(errorText(tester), 'Names are limited to 40 characters.');

      await typeName(tester, 'x' * 40);
      expect(errorText(tester), isNull);
      await confirm(tester);
      expect(container.read(projectsProvider).active.name, hasLength(40));
    });

    projectTest('Enter in the field confirms', (tester) async {
      await pump(tester);
      await choose(tester, 'new-project-button');

      await typeName(tester, 'by enter');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(container.read(projectsProvider).active.name, 'by enter');
    });

    projectTest('Cancel creates nothing', (tester) async {
      await pump(tester);
      await choose(tester, 'new-project-button');

      await typeName(tester, 'never');
      await tester.tap(find.byKey(const Key('project-dialog-cancel-button')));
      await tester.pumpAndSettle();

      expect(container.read(projectsProvider).projects, hasLength(2));
      expect(container.read(projectsProvider).active.id, work.id);
    });
  });

  group('rename', () {
    projectTest('starts with the current name and keeps all the data', (tester) async {
      await pump(tester);
      await choose(tester, 'rename-project-button');
      expect(tester.widget<TextField>(find.byKey(const Key('project-name-field'))).controller!.text, 'commodo');

      await typeName(tester, 'Commodo API');
      await confirm(tester);

      final state = container.read(projectsProvider);
      expect(state.active.id, work.id);
      expect(state.active.name, 'Commodo API');
      expect((await state.store.readFlows()).single.id, 'f1');
      expect(container.read(toastProvider), 'Project renamed to "Commodo API"');
    });

    projectTest('keeping the same name is allowed; another project\'s name is not', (tester) async {
      await pump(tester);
      await choose(tester, 'rename-project-button');

      await confirm(tester);
      expect(find.byKey(const Key('project-name-field')), findsNothing);

      await choose(tester, 'rename-project-button');
      await typeName(tester, 'fin_track_pro');
      await confirm(tester);
      expect(errorText(tester), 'A project with that name already exists.');
    });

    projectTest('it does not offer to change the color', (tester) async {
      await pump(tester);
      await choose(tester, 'rename-project-button');

      expect(find.byKey(const Key('project-color-0')), findsNothing);
    });
  });

  group('delete', () {
    projectTest('asks first, naming the project and what is lost', (tester) async {
      await pump(tester);

      await choose(tester, 'delete-project-button');

      expect(find.textContaining('commodo'), findsWidgets);
      expect(find.textContaining('environments, collections, flows and history'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(container.read(projectsProvider).projects, hasLength(2));
    });

    projectTest('Cancel keeps everything', (tester) async {
      await pump(tester);
      await choose(tester, 'delete-project-button');

      await tester.tap(find.byKey(const Key('delete-project-cancel-button')));
      await tester.pumpAndSettle();

      expect(container.read(projectsProvider).projects, hasLength(2));
      expect((await container.read(projectsProvider).store.readFlows()), hasLength(1));
    });

    projectTest('confirming deletes the project and moves to another', (tester) async {
      await pump(tester);
      await choose(tester, 'delete-project-button');

      await tester.tap(find.byKey(const Key('delete-project-confirm-button')));
      await tester.pumpAndSettle();

      final state = container.read(projectsProvider);
      expect(state.projects.map((p) => p.id), [personal.id]);
      expect(state.active.id, personal.id);
      await expectLater(repo.storeFor(work.id), throwsA(isA<ProjectNotFound>()));
      expect(container.read(toastProvider), 'Project "commodo" deleted');
    });
  });
}
