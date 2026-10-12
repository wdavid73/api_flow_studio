import 'key_value_backend.dart';

/// Not a browser: nothing to persist into, so it behaves like [MemoryBackend].
class LocalStorageBackend extends MemoryBackend {
  LocalStorageBackend({super.capacity});
}
