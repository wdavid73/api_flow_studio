// Saving a text as a file the browser downloads. Only the web has an implementation; anywhere
// else the call fails, because the desktop apps ask where to save with the system dialog.
export 'file_download_stub.dart' if (dart.library.js_interop) 'file_download_web.dart';
