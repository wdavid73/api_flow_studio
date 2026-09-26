import '../models/key_value_entry.dart';
import '../models/request_body.dart';

final RegExp _variablePattern = RegExp(r'\{\{(\w+)\}\}');

/// Replaces every `{{variable}}` token in [template] with its value from
/// [variables]. A token whose name isn't in [variables] is left literal
/// (not blanked out), and text that isn't a well-formed `{{...}}` token is
/// left untouched.
String interpolate(String template, Map<String, String> variables) {
  return template.replaceAllMapped(
    _variablePattern,
    (match) => variables[match.group(1)] ?? match.group(0)!,
  );
}

/// Interpolates the key and value of every enabled entry. Disabled entries
/// are returned unchanged -- interpolation is deferred until they're
/// actually going to be sent.
List<KeyValueEntry> interpolateEntries(
  List<KeyValueEntry> entries,
  Map<String, String> variables,
) {
  return entries
      .map(
        (entry) => entry.enabled
            ? entry.copyWith(
                key: interpolate(entry.key, variables),
                value: interpolate(entry.value, variables),
              )
            : entry,
      )
      .toList();
}

/// Interpolates a [RequestBody]: the raw string of a json body, or the
/// enabled fields of a formUrlEncoded body. `none` is returned unchanged.
RequestBody interpolateBody(RequestBody body, Map<String, String> variables) {
  return body.map(
    none: (b) => b,
    json: (b) => RequestBody.json(interpolate(b.raw, variables)),
    formUrlEncoded: (b) => RequestBody.formUrlEncoded(
      interpolateEntries(b.fields, variables),
    ),
  );
}
