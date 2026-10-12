/// The browser has no room left for what was being saved.
class StorageFullException implements Exception {
  const StorageFullException();

  @override
  String toString() => 'StorageFullException';
}

/// Where [JsonStore] keeps its texts when there is no folder of files: one text per key. The
/// keys are file names with a prefix saying whose they are (`afs:p:<project>:flows.json`).
///
/// A write that does not fit throws [StorageFullException] and leaves what was there untouched.
abstract interface class KeyValueBackend {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> remove(String key);

  /// Every key that starts with [prefix].
  Future<List<String>> keysWithPrefix(String prefix);
}

/// Keeps the texts in memory: tests, and anything that must not outlive the run.
/// [capacity], when given, is the most characters it accepts in total (a write past it throws
/// [StorageFullException]), to test the full-storage paths without a browser.
class MemoryBackend implements KeyValueBackend {
  MemoryBackend({this.capacity});

  final int? capacity;
  final Map<String, String> _values = {};

  int get _used => _values.entries.fold(0, (sum, e) => sum + e.key.length + e.value.length);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    final limit = capacity;
    if (limit != null) {
      final others = _used - (_values.containsKey(key) ? key.length + _values[key]!.length : 0);
      if (others + key.length + value.length > limit) throw const StorageFullException();
    }
    _values[key] = value;
  }

  @override
  Future<void> remove(String key) async => _values.remove(key);

  @override
  Future<List<String>> keysWithPrefix(String prefix) async => [for (final k in _values.keys) if (k.startsWith(prefix)) k];
}
