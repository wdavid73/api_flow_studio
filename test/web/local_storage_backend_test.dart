@TestOn('browser')
library;

import 'package:api_flow_studio/engine/storage/key_value_backend.dart';
import 'package:api_flow_studio/engine/storage/local_storage_backend.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

// These run in Chrome: `fvm flutter test --platform chrome test/web`.
void main() {
  setUp(() => web.window.localStorage.clear());

  test('keeps the texts in localStorage under its own prefix', () async {
    final backend = LocalStorageBackend();
    await backend.write('p:1:flows.json', '[]');

    expect(web.window.localStorage.getItem('afs:p:1:flows.json'), '[]');
    expect(await backend.read('p:1:flows.json'), '[]');
    expect(await backend.read('missing'), isNull);
  });

  test('a second backend over the same storage sees what the first saved', () async {
    await LocalStorageBackend().write('a', 'kept');

    expect(await LocalStorageBackend().read('a'), 'kept');
  });

  test('lists and removes only its own keys', () async {
    web.window.localStorage.setItem('someone-else', 'x');
    final backend = LocalStorageBackend();
    await backend.write('p:1:a', 'x');
    await backend.write('p:2:a', 'x');

    expect(await backend.keysWithPrefix('p:1:'), ['p:1:a']);
    await backend.remove('p:1:a');
    expect(await backend.keysWithPrefix('p:'), ['p:2:a']);
    expect(web.window.localStorage.getItem('someone-else'), 'x');
  });

  test('a write that does not fit throws StorageFullException and keeps the old value', () async {
    final backend = LocalStorageBackend();
    await backend.write('small', 'old');

    // Far past the ~5 MB a browser gives one origin.
    await expectLater(backend.write('small', 'x' * (12 * 1024 * 1024)), throwsA(isA<StorageFullException>()));
    expect(await backend.read('small'), 'old');
  });
}
