import 'dart:convert';
import 'dart:io';

import 'package:api_flow_studio/engine/import/import_registry.dart';
import 'package:api_flow_studio/engine/import/importer.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/collections/collections_provider.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/import/import_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Postman files of the fixtures, all the way into a project.
void main() {
  late JsonStore store;
  late ProviderContainer container;

  String fixture(String name) => File('test/engine/import/postman/fixtures/$name').readAsStringSync();

  setUp(() {
    store = JsonStore.inMemory();
    container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
  });

  test('a collection becomes a new folder tree and an environment that is not active', () async {
    final summary = await applyImport(container.read, runImport(fixture('petstore.postman_collection.json'), importers));

    final collections = await container.read(collectionsProvider.future);
    final environments = await container.read(environmentsProvider.future);
    expect(summary.source, 'Postman collection');
    expect(summary.folders, 5);
    expect(summary.requests, 11);
    expect(summary.environments, 1);
    expect(collections.groups.where((g) => g.parentGroupId == null).map((g) => g.name), ['Petstore API']);
    expect(environments.environments.single.name, 'Petstore API (imported)');
    expect(environments.activeEnvironmentId, isNull);
    expect(summary.warnings, isNotEmpty);
  });

  test('the file still to choose and the empty secret are what is left to fill in', () async {
    final summary = await applyImport(container.read, runImport(fixture('petstore.postman_collection.json'), importers));

    // One enabled file field (photo) and one secret variable with no value (client_secret).
    expect(summary.valuesToFill, 2);
    expect(summary.describe(), 'Imported Postman collection: 11 requests in 5 folders, 1 environment — 2 values to fill in');
  });

  test('no path from the file is left anywhere in the project', () async {
    await applyImport(container.read, runImport(fixture('petstore.postman_collection.json'), importers));

    final onDisk = jsonEncode((await store.readCollections()).endpoints.map((e) => e.toJson()).toList());
    expect(onDisk, isNot(contains('/Users/someone')));
  });

  test('importing it twice numbers the root folder and the environment', () async {
    await applyImport(container.read, runImport(fixture('petstore.postman_collection.json'), importers));
    await applyImport(container.read, runImport(fixture('petstore.postman_collection.json'), importers));

    final collections = await container.read(collectionsProvider.future);
    final environments = await container.read(environmentsProvider.future);
    expect(collections.groups.where((g) => g.parentGroupId == null).map((g) => g.name), ['Petstore API', 'Petstore API (2)']);
    expect(environments.environments.map((e) => e.name), ['Petstore API (imported)', 'Petstore API (imported) (2)']);
  });

  test('an environment file is added next to the existing ones, and not made active', () async {
    final existing = container.read(environmentsProvider.notifier);
    await existing.create('Mine');
    final mine = (await container.read(environmentsProvider.future)).environments.single;
    await existing.setActive(mine.id);

    final summary = await applyImport(container.read, runImport(fixture('staging.postman_environment.json'), importers));

    final state = await container.read(environmentsProvider.future);
    expect(state.environments.map((e) => e.name), ['Mine', 'Staging']);
    expect(state.activeEnvironmentId, mine.id);
    expect(state.environments.last.variables.keys, ['base_url', 'token']);
    expect(summary.describe(), 'Imported Postman environment: 1 environment — 1 value to fill in');
    expect((await container.read(collectionsProvider.future)).groups, isEmpty);
  });

  test('a v1 collection is explained and nothing is added', () async {
    final v1 = jsonEncode({'id': 'a', 'name': 'Old', 'order': [], 'folders': [], 'requests': []});

    expect(() => runImport(v1, importers), throwsA(isA<ImportException>().having((e) => e.message, 'message', contains('Export it again as v2.1'))));
    expect((await container.read(collectionsProvider.future)).groups, isEmpty);
  });
}
