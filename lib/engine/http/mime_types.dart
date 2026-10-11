import '../models/file_paths.dart';

const String _fallback = 'application/octet-stream';

const Map<String, String> _byExtension = {
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'svg': 'image/svg+xml',
  'pdf': 'application/pdf',
  'json': 'application/json',
  'txt': 'text/plain',
  'csv': 'text/csv',
  'xml': 'application/xml',
  'html': 'text/html',
  'zip': 'application/zip',
};

/// The content type to send a file of [path] with, from its extension (case
/// ignored). `dio` does not work this out on its own, and a handful of common
/// types is all a request tester needs; anything else is `application/octet-stream`.
String contentTypeForPath(String path) {
  final name = fileBaseName(path);
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return _fallback;
  return _byExtension[name.substring(dot + 1).toLowerCase()] ?? _fallback;
}
