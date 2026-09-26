import 'dart:io';

import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late JsonStore store;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('environments_provider_test_');
    store = JsonStore(directory: tempDir);
    container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('create adds an environment and persists it', () async {
    await container.read(environmentsProvider.notifier).create('Development');
    final state = await container.read(environmentsProvider.future);

    expect(state.environments, hasLength(1));
    expect(state.environments.single.name, 'Development');

    final persisted = await store.readEnvironments();
    expect(persisted, hasLength(1));
  });

  test('update replaces just the matching environment', () async {
    final notifier = container.read(environmentsProvider.notifier);
    await notifier.create('Development');
    final created = (await container.read(environmentsProvider.future)).environments.single;

    await notifier.updateEnvironment(created.copyWith(name: 'Dev (renamed)'));
    final state = await container.read(environmentsProvider.future);

    expect(state.environments.single.name, 'Dev (renamed)');
    expect((await store.readEnvironments()).single.name, 'Dev (renamed)');
  });

  test('duplicate creates a copy with a new id and " Copy" appended to the name', () async {
    final notifier = container.read(environmentsProvider.notifier);
    await notifier.create('Development');
    final original = (await container.read(environmentsProvider.future)).environments.single;

    await notifier.duplicate(original.id);
    final state = await container.read(environmentsProvider.future);

    expect(state.environments, hasLength(2));
    final copy = state.environments.last;
    expect(copy.id, isNot(original.id));
    expect(copy.name, 'Development Copy');
  });

  test('delete removes the environment and clears active if it was active', () async {
    final notifier = container.read(environmentsProvider.notifier);
    await notifier.create('Development');
    final env = (await container.read(environmentsProvider.future)).environments.single;
    await notifier.setActive(env.id);

    await notifier.delete(env.id);
    final state = await container.read(environmentsProvider.future);

    expect(state.environments, isEmpty);
    expect(state.activeEnvironmentId, isNull);
    expect(await store.readActiveEnvironmentId(), isNull);
  });

  test('setActive persists and survives a fresh provider container (simulated restart)', () async {
    final notifier = container.read(environmentsProvider.notifier);
    await notifier.create('Development');
    final env = (await container.read(environmentsProvider.future)).environments.single;
    await notifier.setActive(env.id);

    final restarted = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(restarted.dispose);
    final state = await restarted.read(environmentsProvider.future);

    expect(state.activeEnvironmentId, env.id);
    expect(state.active?.name, 'Development');
  });
}
