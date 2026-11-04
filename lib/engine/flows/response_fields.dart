import 'dart:convert';

/// The most characters of a value a preview shows before cutting it with `…`.
const int _previewChars = 24;

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
/// into [ResponseFields.omitted].
ResponseFields responseFields(Object? body, {int limit = 200}) {
  if (body is! Map && body is! List) return const ResponseFields([]);

  final fields = <ResponseField>[];
  var omitted = 0;

  void add(String path, String preview, {int? listLength}) {
    if (fields.length < limit) {
      fields.add(ResponseField(path: path, preview: preview, listLength: listLength));
    } else {
      omitted++;
    }
  }

  void visit(String path, Object? value, {bool isRoot = false}) {
    if (value is Map) {
      if (value.isEmpty && !isRoot) add(path, '{}');
      for (final entry in value.entries) {
        visit('$path.${entry.key}', entry.value);
      }
    } else if (value is List) {
      add(path, '[${value.length}]', listLength: value.length);
      if (value.isNotEmpty) visit('$path.0', value.first);
    } else {
      add(path, _preview(value));
    }
  }

  visit('response.body', body, isRoot: true);
  return ResponseFields(fields, omitted: omitted);
}

/// [path] as a step shows it: without the `response.body.` prefix.
String displayPath(String path) {
  if (path == 'response.body') return 'body';
  const prefix = 'response.body.';
  return path.startsWith(prefix) ? path.substring(prefix.length) : path;
}

String _preview(Object? value) {
  if (value == null) return 'null';
  if (value is String) {
    final cut = value.length > _previewChars ? '${value.substring(0, _previewChars)}…' : value;
    return '"$cut"';
  }
  if (value is num || value is bool) return value.toString();
  final text = jsonEncode(value);
  return text.length > _previewChars ? '${text.substring(0, _previewChars)}…' : text;
}
