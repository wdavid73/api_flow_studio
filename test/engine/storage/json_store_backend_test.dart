import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/engine/storage/key_value_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const flow = Flow(id: 'f', name: 'Login', steps: [FlowStep(endpointId: 'e')]);

  test('a backed store keeps its files as prefixed keys and reads them back', () async {
    final backend = MemoryBackend();
    await JsonStore.backed(backend, prefix: 'p:1:').writeFlows([flow]);

    expect(await backend.keysWithPrefix('p:1:'), ['p:1:flows.json']);
    expect((await JsonStore.backed(backend, prefix: 'p:1:').readFlows()).single.name, 'Login');
  });

  test('two stores with different prefixes over one backend do not see each other', () async {
    final backend = MemoryBackend();
    await JsonStore.backed(backend, prefix: 'p:1:').writeFlows([flow]);

    expect(await JsonStore.backed(backend, prefix: 'p:2:').readFlows(), isEmpty);
  });

  test('text that is not JSON reads as the default instead of failing', () async {
    final backend = MemoryBackend();
    await backend.write('flows.json', '{not json');

    expect(await JsonStore.backed(backend).readFlows(), isEmpty);
  });

  test('a write into a full backend throws StorageFullException and keeps what was saved', () async {
    final backend = MemoryBackend(capacity: 400);
    final store = JsonStore.backed(backend);
    await store.writeFlows([flow]);

    final big = [for (var i = 0; i < 100; i++) Flow(id: 'f$i', name: 'A long enough name to fill $i')];
    await expectLater(store.writeFlows(big), throwsA(isA<StorageFullException>()));
    expect((await store.readFlows()).single.name, 'Login');
  });

  test('the app language is saved apart from any project', () async {
    final backend = MemoryBackend();
    await JsonStore.backed(backend, prefix: 'app:').writeAppLocale('es');

    expect(await JsonStore.backed(backend, prefix: 'app:').readAppLocale(), 'es');
    expect(await JsonStore.backed(backend, prefix: 'p:1:').readAppLocale(), isNull);
  });
}
