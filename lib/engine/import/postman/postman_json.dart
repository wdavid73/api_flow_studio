// Postman files vary in shape (a `url` is text or an object, a `description` text or
// `{content}`, an `auth` a list or a map). These readers answer "nothing" for the
// wrong type instead of throwing, so one odd field never sinks a whole import.

Map<String, dynamic>? asMap(Object? value) => value is Map ? Map<String, dynamic>.from(value) : null;

List<dynamic> asList(Object? value) => value is List ? value : const [];

String? asString(Object? value) => value is String ? value : null;

/// The text of a description or a script line: plain text, or the `content` of
/// `{content, type}`; empty for anything else.
String textOf(Object? value) {
  if (value is String) return value;
  if (value is Map) return value['content'] is String ? value['content'] as String : '';
  return '';
}
