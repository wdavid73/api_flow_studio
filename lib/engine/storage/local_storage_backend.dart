// The browser's localStorage where there is one (web); anywhere else a backend that keeps
// the texts in memory, so code that names it still compiles and runs in tests.
export 'local_storage_backend_stub.dart' if (dart.library.js_interop) 'local_storage_backend_web.dart';
