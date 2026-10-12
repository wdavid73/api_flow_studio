import 'package:api_flow_studio/engine/storage/key_value_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes, reads, overwrites and removes a key', () async {
    final backend = MemoryBackend();
    expect(await backend.read('a'), isNull);

    await backend.write('a', '1');
    await backend.write('a', '2');
    expect(await backend.read('a'), '2');

    await backend.remove('a');
    expect(await backend.read('a'), isNull);
  });

  test('lists the keys under a prefix and no others', () async {
    final backend = MemoryBackend();
    await backend.write('p:1:flows.json', 'x');
    await backend.write('p:1:history.json', 'x');
    await backend.write('p:2:flows.json', 'x');

    expect(await backend.keysWithPrefix('p:1:'), unorderedEquals(['p:1:flows.json', 'p:1:history.json']));
    expect(await backend.keysWithPrefix('zzz'), isEmpty);
  });

  test('a write that does not fit throws and leaves the old value', () async {
    final backend = MemoryBackend(capacity: 20);
    await backend.write('k', '0123456789');

    await expectLater(backend.write('k', 'x' * 50), throwsA(isA<StorageFullException>()));
    expect(await backend.read('k'), '0123456789');

    await backend.write('k', 'abc'); // a smaller value for the same key fits again
    expect(await backend.read('k'), 'abc');
  });
}
