import 'package:api_flow_studio/engine/flows/flows_file.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart' show jsonStoreProvider;
import 'package:api_flow_studio/ui/flows/flows_screen.dart';
import 'package:api_flow_studio/ui/import/import_file_dialogs.dart';
import 'package:api_flow_studio/ui/workspace_transfer/workspace_file_dialogs.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SaveDialogs implements WorkspaceFileDialogs {
  String? savedName;
  String? savedText;

  @override
  Future<bool> saveText(String suggestedName, String text) async {
    savedName = suggestedName;
    savedText = text;
    return true;
  }

  @override
  Future<String?> openText() async => null;
}

class _PickDialogs implements ImportFileDialogs {
  _PickDialogs(this.text);

  final String text;

  @override
  Future<PickedImportFile?> pickFile(List<String> extensions) async => PickedImportFile.fromText('flows.json', text);
}

void main() {
  const groups = [Group(id: 'g', name: 'Auth')];
  const endpoints = [
    Endpoint(id: 'e-1', groupId: 'g', name: 'Login', method: 'POST', url: '/login'),
    Endpoint(id: 'e-2', groupId: 'g', name: 'Me', method: 'GET', url: '/me'),
  ];
  const flows = [
    Flow(id: 'f-1', name: 'Login flow', steps: [FlowStep(endpointId: 'e-1')]),
    Flow(id: 'f-2', name: 'Profile flow', steps: [FlowStep(endpointId: 'e-2')]),
  ];

  Future<JsonStore> pump(WidgetTester tester, {required JsonStore store, List<Override> overrides = const []}) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonStoreProvider.overrideWithValue(store), ...overrides],
        child: const MaterialApp(home: Scaffold(body: FlowsScreen())),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  Future<JsonStore> seeded() async {
    final store = JsonStore.inMemory();
    await store.writeCollections(groups: groups, endpoints: endpoints);
    await store.writeFlows(flows);
    return store;
  }

  testWidgets('export saves only the flows left checked', (tester) async {
    final dialogs = _SaveDialogs();
    await pump(tester, store: await seeded(), overrides: [workspaceFileDialogsProvider.overrideWithValue(dialogs)]);

    await tester.tap(find.byKey(const Key('export-flows-button')));
    await tester.pumpAndSettle();
    expect(find.text('Export (2)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('flow-selection-f-2')));
    await tester.pumpAndSettle();
    expect(find.text('Export (1)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('flow-selection-confirm')));
    await tester.pumpAndSettle();

    final saved = FlowsFile.parse(dialogs.savedText!);
    expect(saved.flows.map((f) => f.name), ['Login flow']);
    expect(saved.endpoints.map((e) => e.name), ['Login']);
    expect(dialogs.savedName, 'Login_flow.flows.json');
  });

  testWidgets('"All flows" clears and checks everything; confirm is off with nothing chosen', (tester) async {
    await pump(tester, store: await seeded(), overrides: [workspaceFileDialogsProvider.overrideWithValue(_SaveDialogs())]);

    await tester.tap(find.byKey(const Key('export-flows-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('flow-selection-all')));
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(find.byKey(const Key('flow-selection-confirm'))).onPressed, isNull);

    await tester.tap(find.byKey(const Key('flow-selection-all')));
    await tester.pumpAndSettle();
    expect(find.text('Export (2)'), findsOneWidget);
  });

  testWidgets('import adds the chosen flows and the requests the project lacks, leaving the rest alone', (tester) async {
    final file = buildFlowsFile(flows, groups: groups, endpoints: endpoints);
    final store = JsonStore.inMemory();
    // The project already has the login request, not the profile one.
    await store.writeCollections(
      groups: const [Group(id: 'mine', name: 'Auth')],
      endpoints: const [Endpoint(id: 'mine-login', groupId: 'mine', name: 'Sign in', method: 'POST', url: '/login')],
    );
    await pump(tester, store: store, overrides: [importFileDialogsProvider.overrideWithValue(_PickDialogs(file.encode()))]);

    await tester.tap(find.byKey(const Key('import-flows-button')));
    await tester.pumpAndSettle();
    expect(find.text('Import (2)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('flow-selection-confirm')));
    await tester.pumpAndSettle();

    final imported = await store.readFlows();
    expect(imported.map((f) => f.name), ['Login flow', 'Profile flow']);
    expect(imported.first.steps.single.endpointId, 'mine-login');

    final collections = await store.readCollections();
    expect(collections.groups.map((g) => g.name), ['Auth']);
    expect(collections.endpoints.map((e) => e.name), ['Sign in', 'Me']);
    expect(imported.last.steps.single.endpointId, collections.endpoints.last.id);
  });

  testWidgets('a file that is not a flows file is explained and changes nothing', (tester) async {
    final store = await seeded();
    await pump(tester, store: store, overrides: [importFileDialogsProvider.overrideWithValue(_PickDialogs('{"hello":1}'))]);

    await tester.tap(find.byKey(const Key('import-flows-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('flows-import-error-dialog')), findsOneWidget);
    expect((await store.readFlows()).length, 2);
  });
}
