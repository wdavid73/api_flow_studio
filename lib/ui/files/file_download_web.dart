import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Hands [text] to the browser as a download named [fileName] (the browser puts it in the
/// person's downloads folder or asks where, depending on their settings).
Future<void> downloadTextFile(String fileName, String text, {String mimeType = 'application/json'}) async {
  final blob = web.Blob([utf8.encode(text).toJS].toJS, web.BlobPropertyBag(type: '$mimeType;charset=utf-8'));
  final url = web.URL.createObjectURL(blob);
  try {
    final link = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body!.append(link);
    link.click();
    link.remove();
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
