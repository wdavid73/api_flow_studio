import 'dart:convert';
import 'dart:io';

import 'package:api_flow_studio/engine/import/import_registry.dart';
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

    expect(dialogs.askedFor, ['json', 'yaml', 'yml']);
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

  group('a big file is translated off the main isolate', () {
    // Over 256 KB of text: padded with a long description.
    String bigSpec({bool valid = true}) => jsonEncode({
          if (valid) 'openapi': '3.0.3' else 'swagger': '2.0',
          'info': {'title': 'Big', 'version': '1', 'description': 'x' * 300000},
          'servers': [{'url': 'https://x.test'}],
          'paths': {'/a': {'get': {'summary': 'A'}}},
        });

    Future<void> importBig(WidgetTester tester, String text) async {
      await pumpSidebar(tester);
      dialogs.next = PickedImportFile.fromText('big.json', text);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('import-collections-button')));
        await Future<void>.delayed(const Duration(seconds: 3));
      });
      await tester.pumpAndSettle();
    }

    testWidgets('it still imports', (tester) async {
      await importBig(tester, bigSpec());

      expect(find.text('Big'), findsOneWidget);
      expect((await tester.runAsync(collections))!.endpoints, hasLength(1));
    });

    testWidgets('its refusal reaches the person with the same words', (tester) async {
      await importBig(tester, bigSpec(valid: false));

      expect(find.byKey(const Key('import-error-dialog')), findsOneWidget);
      expect(find.textContaining('Swagger 2.0'), findsOneWidget);
    });
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
        'That file is not a format I can import. Supported: ${importers.map((i) => i.formatName).join(', ')}.',
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

  group('Postman files', () {
    String fixture(String name) => File('test/engine/import/postman/fixtures/$name').readAsStringSync();

    testWidgets('a collection with things left out opens the summary and lists them', (tester) async {
      await pumpSidebar(tester);

      await importFile(tester, PickedImportFile.fromText('petstore.postman_collection.json', fixture('petstore.postman_collection.json')));

      expect(find.byKey(const Key('import-summary-dialog')), findsOneWidget);
      expect(find.text('Imported Postman collection: 11 requests in 5 folders, 1 environment — 2 values to fill in'), findsOneWidget);
      expect(find.text('11 things were left out or changed:'), findsOneWidget);
      expect(find.byKey(const Key('import-warning-0')), findsOneWidget);
      expect(find.text('Collection'), findsWidgets);
      expect(find.text('pre-request script ignored'), findsOneWidget);

      await tester.tap(find.byKey(const Key('import-summary-close')));
      await tester.pumpAndSettle();

      expect(find.text('Petstore API'), findsOneWidget);
      expect((await collections()).endpoints, hasLength(11));
    });

    testWidgets('an environment file whose names had to change opens the summary, and is not made active', (tester) async {
      await pumpSidebar(tester);

      await importFile(tester, PickedImportFile.fromText('staging.postman_environment.json', fixture('staging.postman_environment.json')));

      expect(find.byKey(const Key('import-summary-dialog')), findsOneWidget);
      expect(find.text('Imported Postman environment: 1 environment — 1 value to fill in'), findsOneWidget);
      expect(find.textContaining('base-url → base_url'), findsOneWidget);
      final environments = await store.readEnvironments();
      expect(environments.single.name, 'Staging');
      expect(environments.single.variables.keys, ['base_url', 'token']);
      expect(await store.readActiveEnvironmentId(), isNull);
    });

    testWidgets('a clean environment file only needs a toast', (tester) async {
      await pumpSidebar(tester);
      final text = jsonEncode({
        'name': 'Dev',
        'values': [
          {'key': 'base_url', 'value': 'https://dev.test', 'enabled': true},
        ],
        '_postman_variable_scope': 'environment',
      });

      await importFile(tester, PickedImportFile.fromText('dev.postman_environment.json', text));

      expect(container.read(toastProvider), 'Imported Postman environment: 1 environment');
      expect(find.byKey(const Key('import-summary-dialog')), findsNothing);
    });

    testWidgets('a v1 collection is explained', (tester) async {
      await pumpSidebar(tester);

      await importFile(tester, PickedImportFile.fromText('old.json', jsonEncode({'id': 'a', 'name': 'Old', 'order': [], 'folders': [], 'requests': []})));

      expect(find.byKey(const Key('import-error-dialog')), findsOneWidget);
      expect(find.text('That is a Postman collection v1, which is not supported. Export it again as v2.1.'), findsOneWidget);
      expect((await collections()).groups, isEmpty);
    });
  });

  group('OpenAPI files', () {
    String fixture(String name) => File('test/engine/import/openapi/fixtures/$name').readAsStringSync();

    testWidgets('a spec in YAML with things left out opens the summary and lists them', (tester) async {
      await pumpSidebar(tester);

      await importFile(tester, PickedImportFile.fromText('orders.openapi.yaml', fixture('orders.openapi.yaml')));

      expect(find.byKey(const Key('import-summary-dialog')), findsOneWidget);
      expect(find.text('Imported OpenAPI 3.1 spec: 6 requests in 3 folders, 1 environment — 2 values to fill in'), findsOneWidget);
      expect(find.text('4 things were left out or changed:'), findsOneWidget);
      expect(find.text('webhooks and callbacks were not imported'), findsOneWidget);
      expect(find.text('the file declares no servers; set base_url in the imported environment'), findsOneWidget);

      await tester.tap(find.byKey(const Key('import-summary-close')));
      await tester.pumpAndSettle();

      expect(find.text('Orders API'), findsOneWidget);
      expect((await collections()).endpoints, hasLength(6));
      expect((await store.readEnvironments()).single.name, 'Orders API (imported)');
      expect(await store.readActiveEnvironmentId(), isNull);
    });

    testWidgets('a JSON spec that needs nothing left out only needs a toast', (tester) async {
      await pumpSidebar(tester);
      final text = jsonEncode({
        'openapi': '3.0.3',
        'info': {'title': 'Tiny', 'version': '1'},
        'servers': [{'url': 'https://tiny.test'}],
        'paths': {
          '/ping': {'get': {'summary': 'Ping', 'responses': {'200': {'description': 'ok'}}}},
        },
      });

      await importFile(tester, PickedImportFile.fromText('tiny.json', text));

      expect(container.read(toastProvider), 'Imported OpenAPI 3.0 spec: 1 request in 1 folder, 1 environment');
      expect(find.byKey(const Key('import-summary-dialog')), findsNothing);
    });

    testWidgets('a YAML file that is not valid says so, and a Swagger 2.0 file is explained', (tester) async {
      await pumpSidebar(tester);

      await importFile(tester, PickedImportFile.fromText('broken.yaml', 'openapi: 3.0.0\ninfo: [unclosed\n'));
      expect(find.byKey(const Key('import-error-dialog')), findsOneWidget);
      expect(find.textContaining('That file is not valid YAML'), findsOneWidget);
      await tester.tap(find.byKey(const Key('import-error-close')));
      await tester.pumpAndSettle();

      await importFile(tester, PickedImportFile.fromText('old.yaml', "swagger: '2.0'\ninfo: {title: Old}\n"));
      expect(find.text('That is a Swagger 2.0 file, which is not supported. Convert it to OpenAPI 3 first.'), findsOneWidget);
      expect((await collections()).groups, isEmpty);
    });
  });
}
