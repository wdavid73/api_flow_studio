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

/// The OpenAPI fixtures, all the way into a project.
void main() {
  late JsonStore store;
  late ProviderContainer container;

  String fixture(String name) => File('test/engine/import/openapi/fixtures/$name').readAsStringSync();

  setUp(() {
    store = JsonStore.inMemory();
    container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
  });

  test('a spec becomes a folder tree and an environment that is not active', () async {
    final summary = await applyImport(container.read, runImport(fixture('petstore.openapi.json'), importers));

    final collections = await container.read(collectionsProvider.future);
    final environments = await container.read(environmentsProvider.future);
    expect(summary.source, 'OpenAPI 3.0 spec');
    expect(summary.folders, 4);
    expect(summary.requests, 9);
    expect(summary.environments, 1);
    expect(collections.groups.where((g) => g.parentGroupId == null).map((g) => g.name), ['Petstore']);
    expect(environments.environments.single.name, 'Petstore (imported)');
    expect(environments.activeEnvironmentId, isNull);
  });

  test('the credentials and the files still to choose are what is left to fill in', () async {
    final petstore = await applyImport(container.read, runImport(fixture('petstore.openapi.json'), importers));
    // The bearer token (secret, empty) and the required file of the photo upload.
    expect(petstore.valuesToFill, 2);

    final orders = await applyImport(container.read, runImport(fixture('orders.openapi.yaml'), importers));
    expect(orders.valuesToFill, 2);
    expect(orders.describe(), 'Imported OpenAPI 3.1 spec: 6 requests in 3 folders, 1 environment — 2 values to fill in');
  });

  test('a YAML spec is imported like a JSON one', () async {
    await applyImport(container.read, runImport(fixture('orders.openapi.yaml'), importers));

    final collections = await container.read(collectionsProvider.future);
    expect(collections.endpoints.map((e) => e.name), contains('Create an order'));
    expect(collections.groups.where((g) => g.parentGroupId == null).map((g) => g.name), ['Orders API']);
  });

  test('importing the same spec twice numbers the folder and the environment', () async {
    await applyImport(container.read, runImport(fixture('orders.openapi.yaml'), importers));
    await applyImport(container.read, runImport(fixture('orders.openapi.yaml'), importers));

    final collections = await container.read(collectionsProvider.future);
    final environments = await container.read(environmentsProvider.future);
    expect(collections.groups.where((g) => g.parentGroupId == null).map((g) => g.name), ['Orders API', 'Orders API (2)']);
    expect(environments.environments.map((e) => e.name), ['Orders API (imported)', 'Orders API (imported) (2)']);
  });

  test('nothing from outside the file, and no path, is in the project', () async {
    await applyImport(container.read, runImport(fixture('petstore.openapi.json'), importers));

    final onDisk = jsonEncode((await store.readCollections()).endpoints.map((e) => e.toJson()).toList());
    expect(onDisk, isNot(contains('/Users')));
    expect(onDisk, isNot(contains('example.com/schemas/extra.json')));
  });

  test('a Swagger 2.0 file adds nothing', () async {
    expect(
      () => runImport('{"swagger": "2.0", "info": {"title": "Old"}, "paths": {}}', importers),
      throwsA(isA<ImportException>()),
    );
    expect((await container.read(collectionsProvider.future)).groups, isEmpty);
  });
}
