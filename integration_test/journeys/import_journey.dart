import 'dart:convert';

import 'package:api_flow_studio/ui/import/import_file_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/journey_harness.dart';

/// Journey 14: bring a file of requests into the sidebar with the Import button.
void defineImportJourney(JourneyHarness Function() harness) {
  group('Import journey', () {
    String petstore({bool orphan = false}) => jsonEncode({
          'groups': [
            {'id': 'g1', 'name': 'Petstore', 'parentGroupId': null, 'order': 0},
          ],
          'endpoints': [
            {'id': 'e1', 'groupId': 'g1', 'name': 'List pets', 'method': 'GET', 'url': '{{base_url}}/pets'},
            {'id': 'e2', 'groupId': 'g1', 'name': 'Add pet', 'method': 'POST', 'url': '{{base_url}}/pets'},
            if (orphan) {'id': 'e3', 'groupId': 'nowhere', 'name': 'Lost pet', 'method': 'GET', 'url': '{{base_url}}/lost'},
          ],
        });

    journeyTest('a file of requests becomes a new folder and the app says what came in', (tester) async {
      final app = await harness().launchApp(tester);

      await app.importIntoSidebar(PickedImportFile.fromText('petstore.json', petstore()));

      expect(find.text('Petstore'), findsOneWidget);
      expect(find.text('Imported API Flow Studio collections: 2 requests in 1 folder'), findsOneWidget);
      final collections = await app.store.readCollections();
      expect(collections.endpoints.map((e) => e.name), containsAll(['List pets', 'Add pet']));
    });

    journeyTest('importing the same file twice leaves two folders with different names', (tester) async {
      final app = await harness().launchApp(tester);

      await app.importIntoSidebar(PickedImportFile.fromText('petstore.json', petstore()));
      await app.importIntoSidebar(PickedImportFile.fromText('petstore.json', petstore()));

      expect(find.text('Petstore'), findsOneWidget);
      expect(find.text('Petstore (2)'), findsOneWidget);
    });

    journeyTest('what the file could not bring is listed in a summary', (tester) async {
      final app = await harness().launchApp(tester);

      await app.importIntoSidebar(PickedImportFile.fromText('petstore.json', petstore(orphan: true)));

      expect(find.byKey(const Key('import-summary-dialog')), findsOneWidget);
      expect(find.text('Lost pet'), findsOneWidget);
      await app.tapKey(const Key('import-summary-close'));
      expect(find.byKey(const Key('import-summary-dialog')), findsNothing);
      expect(find.text('Petstore'), findsOneWidget);
    });

    journeyTest('a workspace file is explained, not imported, and nothing changes', (tester) async {
      final app = await harness().launchApp(tester);
      final before = (await app.store.readCollections()).endpoints.length;
      final workspace = jsonEncode({'format': 'api-flow-studio-workspace', 'version': 3, 'project': {'name': 'x'}});

      await app.importIntoSidebar(PickedImportFile.fromText('x.workspace.json', workspace));

      expect(find.byKey(const Key('import-error-dialog')), findsOneWidget);
      expect(find.textContaining('Use Project ▸ Import workspace…'), findsOneWidget);
      await app.tapKey(const Key('import-error-close'));
      expect((await app.store.readCollections()).endpoints, hasLength(before));
    });

    journeyTest('cancelling the file dialog changes nothing', (tester) async {
      final app = await harness().launchApp(tester);
      final before = (await app.store.readCollections()).groups.length;

      await app.importIntoSidebar(null);

      expect((await app.store.readCollections()).groups, hasLength(before));
      expect(find.byType(AlertDialog), findsNothing);
    });

    group('from Postman', () {
      /// A small collection with what matters: a folder, a request, a variable, a script
      /// (which cannot come along) and a file field (whose path never does).
      String postmanCollection() => jsonEncode({
            'info': {'name': 'Orders API', 'schema': 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json'},
            'variable': [
              {'key': 'base-url', 'value': 'https://orders.test'},
            ],
            'item': [
              {
                'name': 'Orders',
                'item': [
                  {
                    'name': 'Create order',
                    'event': [
                      {'listen': 'prerequest', 'script': {'exec': ['pm.environment.set("x", 1);']}},
                    ],
                    'request': {
                      'method': 'POST',
                      'url': '{{base-url}}/orders',
                      'body': {
                        'mode': 'formdata',
                        'formdata': [
                          {'key': 'receipt', 'type': 'file', 'src': '/Users/someone/receipt.pdf'},
                        ],
                      },
                    },
                  },
                ],
              },
            ],
          });

      journeyTest('a collection brings its folders, an environment that is not active, and a summary of what was left out', (tester) async {
        final app = await harness().launchApp(tester);
        final activeBefore = await app.store.readActiveEnvironmentId();

        await app.importIntoSidebar(PickedImportFile.fromText('orders.postman_collection.json', postmanCollection()));

        expect(find.byKey(const Key('import-summary-dialog')), findsOneWidget);
        expect(find.text('Imported Postman collection: 1 request in 2 folders, 1 environment — 1 value to fill in'), findsOneWidget);
        expect(find.text('pre-request script ignored'), findsOneWidget);
        expect(find.text('file field "receipt" needs a file chosen'), findsOneWidget);
        await app.tapKey(const Key('import-summary-close'));

        expect(find.text('Orders API'), findsOneWidget);
        final environments = await app.store.readEnvironments();
        final imported = environments.firstWhere((e) => e.name == 'Orders API (imported)');
        expect(imported.variables['base_url']!.value, 'https://orders.test');
        expect(await app.store.readActiveEnvironmentId(), activeBefore, reason: 'an imported environment is never made active');

        final request = (await app.store.readCollections()).endpoints.firstWhere((e) => e.name == 'Create order');
        expect(request.url, '{{base_url}}/orders', reason: 'the variable was renamed so it resolves');
        final fields = request.body.maybeMap(multipart: (b) => b.fields, orElse: () => throw StateError('not multipart'));
        expect(fields.single.value, isEmpty, reason: 'no path from the file');
      });

      journeyTest('an environment file adds an environment', (tester) async {
        final app = await harness().launchApp(tester);
        final before = (await app.store.readEnvironments()).length;
        final text = jsonEncode({
          'name': 'Staging',
          'values': [
            {'key': 'base-url', 'value': 'https://staging.test', 'enabled': true},
          ],
          '_postman_variable_scope': 'environment',
        });

        await app.importIntoSidebar(PickedImportFile.fromText('staging.postman_environment.json', text));

        expect(find.byKey(const Key('import-summary-dialog')), findsOneWidget, reason: 'the renamed variable is a warning');
        await app.tapKey(const Key('import-summary-close'));
        final environments = await app.store.readEnvironments();
        expect(environments, hasLength(before + 1));
        expect(environments.last.name, 'Staging');
        expect(environments.last.variables.keys, ['base_url']);
      });
    });
  });
}
