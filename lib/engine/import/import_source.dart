import 'dart:convert';

/// The text of a file to import, with its JSON decoded once, on demand: several
/// importers get to look at the same file while the core finds the one that owns
/// it, and a large file should not be parsed again for each of them.
class ImportSource {
  ImportSource(this.text, {this.fileName});

  final String text;

  /// The name of the file it came from, when known; only used for messages.
  final String? fileName;

  bool _decoded = false;
  Object? _json;

  /// The decoded JSON, or null when [text] is not JSON (a YAML spec, a damaged
  /// file). Never throws.
  Object? get json {
    if (!_decoded) {
      _decoded = true;
      try {
        _json = jsonDecode(text);
      } on FormatException {
        _json = null;
      }
    }
    return _json;
  }
}
