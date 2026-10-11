// Imported files vary in shape (a Postman `url` is text or an object, an OpenAPI `example`
// anything at all). These readers answer "nothing" for the wrong type instead of throwing,
// so one odd field never sinks a whole import. They read JSON and YAML documents alike
// (a `YamlMap` is a `Map`) without copying the whole document.

/// [value] as a map with text keys, or null. YAML writes `200:` as a number and `yes:` as a
/// boolean, so the keys are turned into text rather than cast.
Map<String, dynamic>? asMap(Object? value) {
  if (value is! Map) return null;
  if (value is Map<String, dynamic>) return value;
  return {for (final entry in value.entries) '${entry.key}': entry.value};
}

List<dynamic> asList(Object? value) => value is List ? value : const [];

String? asString(Object? value) => value is String ? value : null;

/// The text of a description or a script line: plain text, or the `content` of
/// `{content, type}`; empty for anything else.
String textOf(Object? value) {
  if (value is String) return value;
  if (value is Map) return value['content'] is String ? value['content'] as String : '';
  return '';
}
