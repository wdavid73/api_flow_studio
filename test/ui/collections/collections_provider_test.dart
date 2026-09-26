import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/collections/collections_provider.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart' show jsonStoreProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late JsonStore store;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('collections_provider_test_');
    store = JsonStore(directory: tempDir);
    container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('createGroup persists a root group', () async {
    final notifier = container.read(collectionsProvider.notifier);
    await notifier.createGroup('Authentication API');

    final state = await container.read(collectionsProvider.future);
    expect(state.groups.single.name, 'Authentication API');
    expect(state.groups.single.parentGroupId, isNull);
    expect((await store.readCollections()).groups, hasLength(1));
  });

  test('a nested category/subcategory/endpoint structure persists and rebuilds into a tree',
      () async {
    final notifier = container.read(collectionsProvider.notifier);
    final category = await notifier.createGroup('Authentication API');
    final subcategory = await notifier.createGroup('Tokens', parentGroupId: category.id);
    await notifier.createEndpoint(Endpoint(
      id: 'e-1',
      groupId: subcategory.id,
      name: 'Refresh',
      method: 'POST',
      url: '{{base_url}}/auth/refresh',
    ));

    final state = await container.read(collectionsProvider.future);
    final tree = buildGroupTree(state.groups, state.endpoints);

    expect(tree, hasLength(1));
    expect(tree.single.group.name, 'Authentication API');
    expect(tree.single.children, hasLength(1));
    expect(tree.single.children.single.group.name, 'Tokens');
    expect(tree.single.children.single.endpoints.single.name, 'Refresh');
    expect(tree.single.endpoints, isEmpty);
  });

  test('deleteGroup blocks when the group still has a child group', () async {
    final notifier = container.read(collectionsProvider.notifier);
    final parent = await notifier.createGroup('Parent');
    await notifier.createGroup('Child', parentGroupId: parent.id);

    expect(
      () => notifier.deleteGroup(parent.id),
      throwsA(isA<GroupNotEmptyException>()),
    );
  });

  test('deleteGroup blocks when the group still has an endpoint', () async {
    final notifier = container.read(collectionsProvider.notifier);
    final group = await notifier.createGroup('Group');
    await notifier.createEndpoint(Endpoint(
      id: 'e-1',
      groupId: group.id,
      name: 'Login',
      method: 'POST',
      url: '/login',
    ));

    expect(
      () => notifier.deleteGroup(group.id),
      throwsA(isA<GroupNotEmptyException>()),
    );
  });

  test('deleteGroup succeeds for an empty group', () async {
    final notifier = container.read(collectionsProvider.notifier);
    final group = await notifier.createGroup('Empty Group');

    await notifier.deleteGroup(group.id);

    final state = await container.read(collectionsProvider.future);
    expect(state.groups, isEmpty);
  });

  test('renameGroup persists the new name', () async {
    final notifier = container.read(collectionsProvider.notifier);
    final group = await notifier.createGroup('Old Name');

    await notifier.renameGroup(group.id, 'New Name');

    expect((await store.readCollections()).groups.single.name, 'New Name');
  });

  test('moveEndpoint changes which group an endpoint belongs to', () async {
    final notifier = container.read(collectionsProvider.notifier);
    final groupA = await notifier.createGroup('A');
    final groupB = await notifier.createGroup('B');
    final endpoint = await notifier.createEndpoint(Endpoint(
      id: 'e-1',
      groupId: groupA.id,
      name: 'Login',
      method: 'POST',
      url: '/login',
    ));

    await notifier.moveEndpoint(endpoint.id, groupB.id);

    final state = await container.read(collectionsProvider.future);
    expect(state.endpoints.single.groupId, groupB.id);
  });

  test('deleteEndpoint removes it', () async {
    final notifier = container.read(collectionsProvider.notifier);
    final group = await notifier.createGroup('Group');
    final endpoint = await notifier.createEndpoint(Endpoint(
      id: 'e-1',
      groupId: group.id,
      name: 'Login',
      method: 'POST',
      url: '/login',
    ));

    await notifier.deleteEndpoint(endpoint.id);

    final state = await container.read(collectionsProvider.future);
    expect(state.endpoints, isEmpty);
  });
}
