import 'dart:convert';

/// The most characters of a value a preview shows before cutting it with `…`.
const int _previewChars = 24;

/// How deep a response is walked. A container further down is one leaf
/// (`{…}` or `[n]`): real payloads are nowhere near this deep, and a
/// pathological one must not overflow the stack while the canvas builds.
const int maxFieldDepth = 32;

/// One value of a response a step can extract: its full dot path
/// (`response.body.user.id`) and a short preview of what it held.
class ResponseField {
  const ResponseField({required this.path, required this.preview, this.listLength});

  final String path;
  final String preview;

  /// The number of items, when this field is a list (null otherwise).
  final int? listLength;
}

/// The fields of a response body, at most a limit of them, plus how many
/// were left out.
class ResponseFields {
  const ResponseFields(this.fields, {this.omitted = 0});

  final List<ResponseField> fields;
  final int omitted;
}

/// Flattens a decoded JSON [body] into its leaves, in the order the response
/// lists them. A list is a leaf of its own (with its length) and only its
/// item `0` is expanded below it, so a list of a thousand objects costs as
/// much as one. Anything that is not a `Map` or a `List` (text, a number, no
/// body) has no fields.
///
/// Past [limit] leaves no more fields are built; the rest are only counted
/// into [ResponseFields.omitted], without building their paths or previews.
/// Containers deeper than [maxFieldDepth] are leaves.
ResponseFields responseFields(Object? body, {int limit = 200}) {
  if (body is! Map && body is! List) return const ResponseFields([]);

  final fields = <ResponseField>[];
  var omitted = 0;

  void visit(String path, Object? value, int depth) {
    if (fields.length >= limit) {
      omitted += _leafCount(value, depth);
      return;
    }
    if ((value is Map || value is List) && depth >= maxFieldDepth) {
      fields.add(ResponseField(path: path, preview: value is List ? '[${value.length}]' : '{…}'));
    } else if (value is Map) {
      if (value.isEmpty && depth > 0) fields.add(ResponseField(path: path, preview: '{}'));
      for (final entry in value.entries) {
        visit('$path.${entry.key}', entry.value, depth + 1);
      }
    } else if (value is List) {
      fields.add(ResponseField(path: path, preview: '[${value.length}]', listLength: value.length));
      if (value.isNotEmpty) visit('$path.0', value.first, depth + 1);
    } else {
      fields.add(ResponseField(path: path, preview: previewValue(value)));
    }
  }

  visit('response.body', body, 0);
  return ResponseFields(fields, omitted: omitted);
}

/// How many fields [responseFields] would list for [value] at [depth], had it
/// no limit -- the same walk, counting only.
int _leafCount(Object? value, int depth) {
  if ((value is Map || value is List) && depth >= maxFieldDepth) return 1;
  if (value is Map) {
    var count = value.isEmpty && depth > 0 ? 1 : 0;
    for (final child in value.values) {
      count += _leafCount(child, depth + 1);
    }
    return count;
  }
  if (value is List) return 1 + (value.isEmpty ? 0 : _leafCount(value.first, depth + 1));
  return 1;
}

/// [path] as a step shows it: without the `response.body.` prefix.
String displayPath(String path) {
  if (path == 'response.body') return 'body';
  const prefix = 'response.body.';
  return path.startsWith(prefix) ? path.substring(prefix.length) : path;
}

/// A short, one-line rendering of [value]: strings quoted, long text cut with `…`.
String previewValue(Object? value) {
  if (value == null) return 'null';
  if (value is String) {
    final cut = value.length > _previewChars ? '${value.substring(0, _previewChars)}…' : value;
    return '"$cut"';
  }
  if (value is num || value is bool) return value.toString();
  final text = jsonEncode(value);
  return text.length > _previewChars ? '${text.substring(0, _previewChars)}…' : text;
}
