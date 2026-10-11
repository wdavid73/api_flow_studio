import 'dart:convert';

import 'package:api_flow_studio/engine/import/importer.dart' show maxImportFileBytes;
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/collections/collections_provider.dart';
import 'package:api_flow_studio/ui/collections/sidebar_tree.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart' show jsonStoreProvider;
import 'package:api_flow_studio/ui/import/import_file_dialogs.dart';
import 'package:api_flow_studio/ui/shell/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeImportFileDialogs implements ImportFileDialogs {
  PickedImportFile? next;
  List<String>? askedFor;
  int asked = 0;

  @override
  Future<PickedImportFile?> pickFile(List<String> extensions) async {
    askedFor = extensions;
    asked++;
    return next;
  }
}

String collectionsJson({String folder = 'Petstore', bool orphan = false}) => jsonEncode({
      'groups': [
        {'id': 'g1', 'name': folder, 'parentGroupId': null, 'order': 0},
      ],
      'endpoints': [
        for (final id in ['e1', 'e2'])
          {'id': id, 'groupId': 'g1', 'name': 'Request $id', 'method': 'GET', 'url': 'https://x.test/$id'},
        if (orphan) {'id': 'e3', 'groupId': 'nowhere', 'name': 'Lost request', 'method': 'GET', 'url': 'https://x.test/e3'},
      ],
    });

void main() {
  late FakeImportFileDialogs dialogs;
  late JsonStore store;
  late ProviderContainer container;

  Future<void> pumpSidebar(WidgetTester tester) async {
    dialogs = FakeImportFileDialogs();
    store = JsonStore.inMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonStoreProvider.overrideWithValue(store), importFileDialogsProvider.overrideWithValue(dialogs)],
        child: const MaterialApp(home: Scaffold(body: SizedBox(width: 300, child: SidebarTree()))),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(tester.element(find.byType(SidebarTree)));
  }

  Future<void> importFile(WidgetTester tester, PickedImportFile? file) async {
    dialogs.next = file;
    await tester.tap(find.byKey(const Key('import-collections-button')));
    await tester.pumpAndSettle();
  }

  Future<CollectionsState> collections() => container.read(collectionsProvider.future);

  testWidgets('the button offers the extensions the importers accept', (tester) async {
    await pumpSidebar(tester);

    await importFile(tester, null);

    expect(dialogs.askedFor, ['json']);
    expect(find.byTooltip('Import…'), findsOneWidget);
  });

  testWidgets('importing a collections file adds its folder and says what came in', (tester) async {
    await pumpSidebar(tester);

    await importFile(tester, PickedImportFile.fromText('petstore.json', collectionsJson()));

    expect(find.text('Petstore'), findsOneWidget);
    expect(container.read(toastProvider), 'Imported API Flow Studio collections: 2 requests in 1 folder');
    expect((await collections()).endpoints, hasLength(2));
    expect(find.byKey(const Key('import-summary-dialog')), findsNothing);
  });

  testWidgets('importing the same file again numbers the folder', (tester) async {
    await pumpSidebar(tester);

    await importFile(tester, PickedImportFile.fromText('petstore.json', collectionsJson()));
    await importFile(tester, PickedImportFile.fromText('petstore.json', collectionsJson()));

    expect(find.text('Petstore'), findsOneWidget);
    expect(find.text('Petstore (2)'), findsOneWidget);
  });

  testWidgets('warnings open the summary with the list, and Close dismisses it', (tester) async {
    await pumpSidebar(tester);

    await importFile(tester, PickedImportFile.fromText('petstore.json', collectionsJson(orphan: true)));

    expect(find.byKey(const Key('import-summary-dialog')), findsOneWidget);
    expect(find.text('Imported API Flow Studio collections: 2 requests in 1 folder'), findsOneWidget);
    expect(find.byKey(const Key('import-warning-0')), findsOneWidget);
    expect(find.text('Lost request'), findsOneWidget);
    expect(find.text('its folder is not in the file; skipped'), findsOneWidget);
    expect(container.read(toastProvider), isNull, reason: 'the dialog is the report; no toast on top');

    await tester.tap(find.byKey(const Key('import-summary-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('import-summary-dialog')), findsNothing);
    expect((await collections()).endpoints, hasLength(2));
  });

  testWidgets('cancelling the dialog does nothing', (tester) async {
    await pumpSidebar(tester);

    await importFile(tester, null);

    expect(dialogs.asked, 1);
    expect(container.read(toastProvider), isNull);
    expect((await collections()).groups, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  group('a file that cannot be imported says why and changes nothing', () {
    Future<void> expectRefused(WidgetTester tester, PickedImportFile file, String message) async {
      await pumpSidebar(tester);
      await importFile(tester, file);

      expect(find.byKey(const Key('import-error-dialog')), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect((await collections()).groups, isEmpty);
      expect(container.read(toastProvider), isNull);

      await tester.tap(find.byKey(const Key('import-error-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('import-error-dialog')), findsNothing);
    }

    testWidgets('a workspace file points to the right command', (tester) async {
      final workspace = jsonEncode({'format': 'api-flow-studio-workspace', 'version': 3, 'project': {'name': 'x'}});

      await expectRefused(
        tester,
        PickedImportFile.fromText('x.workspace.json', workspace),
        'This is a workspace file. Use Project ▸ Import workspace… to open it as a new project.',
      );
    });

    testWidgets('a format nobody here reads lists what is supported', (tester) async {
      await expectRefused(
        tester,
        PickedImportFile.fromText('thing.json', '{"hello": 1}'),
        'That file is not a format I can import. Supported: API Flow Studio collections.',
      );
    });

    testWidgets('a .json file that is not JSON', (tester) async {
      await expectRefused(tester, PickedImportFile.fromText('broken.json', '{"groups": ['), 'That file is not valid JSON.');
    });

    testWidgets('a file with nothing in it', (tester) async {
      await expectRefused(
        tester,
        PickedImportFile.fromText('empty.json', '{"groups": [], "endpoints": []}'),
        'Nothing to import: API Flow Studio collections had no requests.',
      );
    });

    testWidgets('a file over 32 MB is refused without reading it', (tester) async {
      var read = false;
      final huge = PickedImportFile(
        name: 'huge.json',
        sizeBytes: maxImportFileBytes + 1,
        read: () async {
          read = true;
          return '{}';
        },
      );

      await expectRefused(tester, huge, 'That file is too large to import (the limit is 32 MB).');
      expect(read, isFalse);
    });

    testWidgets('a file that cannot be read', (tester) async {
      final unreadable = PickedImportFile(name: 'locked.json', sizeBytes: 10, read: () async => throw const FormatException('bad bytes'));

      await expectRefused(tester, unreadable, 'Could not read that file.');
    });

    testWidgets('a file at exactly the limit is not refused for its size', (tester) async {
      await pumpSidebar(tester);
      final text = collectionsJson();

      await importFile(tester, PickedImportFile(name: 'edge.json', sizeBytes: maxImportFileBytes, read: () async => text));

      expect(find.byKey(const Key('import-error-dialog')), findsNothing);
      expect((await collections()).endpoints, hasLength(2));
    });
  });

  testWidgets('a Form Data request arrives without its file path', (tester) async {
    await pumpSidebar(tester);
    final text = jsonEncode({
      'groups': [
        {'id': 'g', 'name': 'Uploads'},
      ],
      'endpoints': [
        {
          'id': 'e',
          'groupId': 'g',
          'name': 'Upload',
          'method': 'POST',
          'url': 'https://x.test/up',
          'body': {
            'runtimeType': 'multipart',
            'fields': [
              {'name': 'loot', 'kind': 'file', 'value': '/Users/victim/.ssh/id_rsa'},
            ],
          },
        },
      ],
    });

    await importFile(tester, PickedImportFile.fromText('uploads.json', text));

    final fields = (await collections()).endpoints.single.body.maybeMap(multipart: (b) => b.fields, orElse: () => throw StateError('not multipart'));
    expect(fields.single.value, '');
  });
}
