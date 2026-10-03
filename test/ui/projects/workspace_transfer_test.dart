import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/projects/project.dart';
import 'package:api_flow_studio/engine/projects/projects_repository.dart';
import 'package:api_flow_studio/engine/workspace/workspace_file.dart';
import 'package:api_flow_studio/ui/projects/project_switcher.dart';
import 'package:api_flow_studio/ui/projects/projects_provider.dart';
import 'package:api_flow_studio/ui/shell/app_toast.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:api_flow_studio/ui/workspace_transfer/workspace_file_dialogs.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the system file dialogs: records what was saved and answers
/// with whatever the test set up.
class _FakeDialogs implements WorkspaceFileDialogs {
  String? savedName;
  String? savedText;
  bool saveAccepted = true;
  Object? saveError;
  String? textToOpen;
  int opens = 0;

  @override
  Future<bool> saveText(String suggestedName, String text) async {
    if (saveError != null) throw saveError!;
    savedName = suggestedName;
    savedText = text;
    return saveAccepted;
  }

  @override
  Future<String?> openText() async {
    opens++;
    return textToOpen;
  }
}

/// A widget test that lets the toast's timer run out before it ends.
void transferTest(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pump(toastDuration + const Duration(milliseconds: 1));
  });
}

void main() {
  late ProjectsRepository repo;
  late Project work;
  late ProviderContainer container;
  late _FakeDialogs dialogs;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    repo = ProjectsRepository.inMemory();
    work = await repo.create('commodo', colorIndex: 2);
    final store = await repo.storeFor(work.id);
    await store.writeEnvironments([
      const Environment(id: 'dev', name: 'Dev', variables: {
        'base_url': EnvironmentVariable(value: 'https://dev.test'),
        'api_key': EnvironmentVariable(value: 'S3CR3T-VALUE', secret: true),
      }),
    ]);
    await store.writeCollections(
      groups: const [Group(id: 'g1', name: 'API')],
      endpoints: const [Endpoint(id: 'e1', groupId: 'g1', name: 'List', method: 'GET', url: '{{base_url}}/items')],
    );
    await store.writeFlows([const Flow(id: 'f1', name: 'Flow', steps: [FlowStep(endpointId: 'e1')])]);

    dialogs = _FakeDialogs();
    final state = await ProjectsController.load(repo);
    container = ProviderContainer(overrides: [
      projectsRepositoryProvider.overrideWithValue(repo),
      initialProjectsStateProvider.overrideWithValue(state),
      workspaceFileDialogsProvider.overrideWithValue(dialogs),
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

  Future<void> choose(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(const Key('project-switcher')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  const validFile = '''
{
  "format": "api-flow-studio-workspace",
  "version": 1,
  "exportedAt": "2026-10-03T10:00:00.000Z",
  "project": {"name": "shared", "colorIndex": 5},
  "environments": [
    {"id": "x", "name": "Dev", "variables": {"key": {"value": "", "secret": true}, "url": {"value": "https://x.test", "secret": false}}}
  ],
  "collections": {"groups": [{"id": "g", "name": "Group"}], "endpoints": [{"id": "e", "groupId": "g", "name": "One", "method": "GET", "url": "{{url}}"}]},
  "flows": [],
  "hostNotes": {}
}
''';

  group('the menu', () {
    transferTest('offers Export and Import after the project actions', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const Key('project-switcher')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('export-workspace-button')), findsOneWidget);
      expect(find.byKey(const Key('import-workspace-button')), findsOneWidget);
    });
  });

  group('export', () {
    transferTest('saves the active project under a suggested name and says so', (tester) async {
      await pump(tester);

      await choose(tester, 'export-workspace-button');

      expect(dialogs.savedName, 'commodo.workspace.json');
      final saved = WorkspaceFile.parse(dialogs.savedText!);
      expect(saved.name, 'commodo');
      expect(saved.colorIndex, 2);
      expect(saved.endpoints.single.name, 'List');
      expect(saved.flows.single.name, 'Flow');
      expect(container.read(toastProvider), 'Workspace "commodo" exported — secrets are not included');
    });

    transferTest('the file holds no secret value', (tester) async {
      await pump(tester);

      await choose(tester, 'export-workspace-button');

      expect(dialogs.savedText, isNot(contains('S3CR3T-VALUE')));
      expect(dialogs.savedText, contains('"secret": true'));
    });

    transferTest('cancelling the save dialog does nothing and shows no message', (tester) async {
      await pump(tester);
      dialogs.saveAccepted = false;

      await choose(tester, 'export-workspace-button');

      expect(container.read(toastProvider), isNull);
    });

    transferTest('a failure while saving is reported instead of crashing', (tester) async {
      await pump(tester);
      dialogs.saveError = Exception('disk full');

      await choose(tester, 'export-workspace-button');

      expect(container.read(toastProvider), startsWith('Could not save the workspace'));
      expect(tester.takeException(), isNull);
    });
  });

  group('import', () {
    transferTest('creates the project, makes it the active one and says what is left to fill in', (tester) async {
      await pump(tester);
      dialogs.textToOpen = validFile;

      await choose(tester, 'import-workspace-button');

      final state = container.read(projectsProvider);
      expect(state.active.name, 'shared');
      expect(state.active.colorIndex, 5);
      expect(state.projects.map((p) => p.name), ['commodo', 'shared']);
      expect((await state.store.readCollections()).endpoints.single.name, 'One');
      expect(container.read(toastProvider), 'Imported "shared" — 1 secret value to fill in');
    });

    transferTest('the original project is untouched', (tester) async {
      await pump(tester);
      dialogs.textToOpen = validFile;

      await choose(tester, 'import-workspace-button');

      final original = await repo.storeFor(work.id);
      expect((await original.readCollections()).endpoints.single.id, 'e1');
      expect((await original.readEnvironments()).single.variables['api_key']!.value, 'S3CR3T-VALUE');
    });

    transferTest('importing the same file twice makes two projects', (tester) async {
      await pump(tester);
      dialogs.textToOpen = validFile;

      await choose(tester, 'import-workspace-button');
      await choose(tester, 'import-workspace-button');

      expect(container.read(projectsProvider).projects.map((p) => p.name), ['commodo', 'shared', 'shared (2)']);
    });

    transferTest('cancelling the open dialog does nothing', (tester) async {
      await pump(tester);
      dialogs.textToOpen = null;

      await choose(tester, 'import-workspace-button');

      expect(dialogs.opens, 1);
      expect(container.read(projectsProvider).projects, hasLength(1));
      expect(container.read(toastProvider), isNull);
    });

    transferTest('a file that is not a workspace shows why and changes nothing', (tester) async {
      await pump(tester);
      dialogs.textToOpen = '{"groups": [], "endpoints": []}';

      await choose(tester, 'import-workspace-button');

      expect(find.byKey(const Key('import-error-dialog')), findsOneWidget);
      expect(find.text('That file is not an API Flow Studio workspace.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('import-error-ok-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import-error-dialog')), findsNothing);
      expect(container.read(projectsProvider).projects, hasLength(1));
      expect(container.read(projectsProvider).active.id, work.id);
    });

    transferTest('a file from a newer version says to update', (tester) async {
      await pump(tester);
      dialogs.textToOpen = validFile.replaceFirst('"version": 1', '"version": 2');

      await choose(tester, 'import-workspace-button');

      expect(find.textContaining('newer version'), findsOneWidget);
      expect(container.read(projectsProvider).projects, hasLength(1));
    });

    transferTest('text that is not even JSON is rejected the same way', (tester) async {
      await pump(tester);
      dialogs.textToOpen = 'hello';

      await choose(tester, 'import-workspace-button');

      expect(find.text('That file is not valid JSON.'), findsOneWidget);
    });
  });
}
