import 'package:web/web.dart' as web;

import 'key_value_backend.dart';

/// The browser's `localStorage`, shared by every page of the same origin, so every key carries
/// [namespace] (`afs:`) to stay clear of anything else stored there. It holds about 5 MB: a write
/// that does not fit throws [StorageFullException] and the old value stays.
class LocalStorageBackend implements KeyValueBackend {
  LocalStorageBackend({this.namespace = 'afs:'});

  final String namespace;

  web.Storage get _storage => web.window.localStorage;

  @override
  Future<String?> read(String key) async => _storage.getItem('$namespace$key');

  @override
  Future<void> write(String key, String value) async {
    try {
      _storage.setItem('$namespace$key', value);
    } catch (error) {
      // dart:js_interop surfaces a DOMException as an object whose name is QuotaExceededError
      // (or NS_ERROR_DOM_QUOTA_REACHED in old Firefox).
      final text = '$error';
      if (text.contains('QuotaExceeded') || text.contains('QUOTA')) throw const StorageFullException();
      rethrow;
    }
  }

  @override
  Future<void> remove(String key) async => _storage.removeItem('$namespace$key');

  @override
  Future<List<String>> keysWithPrefix(String prefix) async {
    final full = '$namespace$prefix';
    return [
      for (var i = 0; i < _storage.length; i++)
        if (_storage.key(i) case final key? when key.startsWith(full)) key.substring(namespace.length),
    ];
  }
}
