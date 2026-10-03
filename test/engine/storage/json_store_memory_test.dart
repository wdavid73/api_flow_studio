import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// The web build can't touch the filesystem (`Platform.resolvedExecutable`
/// throws), so the store falls back to memory there. These tests exercise
/// that backend directly.
void main() {
  test('reads defaults before anything was written', () async {
    final store = JsonStore.inMemory();

    expect(await store.readEnvironments(), isEmpty);
    expect(await store.readActiveEnvironmentId(), isNull);
    expect((await store.readCollections()).groups, isEmpty);
  });

  test('round-trips environments and the active environment id', () async {
    final store = JsonStore.inMemory();
    const env = Environment(id: 'e1', name: 'Dev');

    await store.writeEnvironments([env]);
    await store.writeActiveEnvironmentId('e1');

    expect((await store.readEnvironments()).single.name, 'Dev');
    expect(await store.readActiveEnvironmentId(), 'e1');
  });

  test('each store instance has its own memory', () async {
    final a = JsonStore.inMemory();
    final b = JsonStore.inMemory();

    await a.writeEnvironments([const Environment(id: 'e1', name: 'Dev')]);

    expect(await b.readEnvironments(), isEmpty);
  });

  test('history appends and trims in memory', () async {
    final store = JsonStore.inMemory();
    final entry = HistoryEntry(
      id: 'h1',
      endpointId: 'ep',
      timestamp: DateTime(2026),
      elapsedMs: 5,
      status: 200,
    );

    await store.appendHistoryEntry('ep', entry);
    await store.appendHistoryEntry('ep', entry.copyWith(id: 'h2'));

    expect((await store.readHistory('ep')).map((e) => e.id), ['h1', 'h2']);
  });
}
