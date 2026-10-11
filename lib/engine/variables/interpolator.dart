import '../models/key_value_entry.dart';
import '../models/request_body.dart';
import 'dynamic_values.dart';

final RegExp _variablePattern = RegExp(r'\{\{(\w+)\}\}');
final RegExp _dynamicPattern = RegExp(r'\{\{\$(\w+)\}\}');

/// Replaces every `{{variable}}` token in [template] with its value from
/// [variables]. A token whose name isn't in [variables] is left literal
/// (not blanked out), and text that isn't a well-formed `{{...}}` token is
/// left untouched.
///
/// With [dynamicValues], `{{$name}}` tokens (`{{$uuid}}`, `{{$randomEmail}}`…)
/// are then replaced with a fresh generated value each, after the normal
/// variables so a variable's value may itself contain one. An unknown token
/// stays literal, and so does every token when [dynamicValues] is null --
/// previews and curl export pass none, because the real value only exists at
/// send time.
String interpolate(
  String template,
  Map<String, String> variables, {
  DynamicValues? dynamicValues,
}) {
  final resolved = template.replaceAllMapped(
    _variablePattern,
    (match) => variables[match.group(1)] ?? match.group(0)!,
  );
  if (dynamicValues == null) return resolved;
  return resolved.replaceAllMapped(
    _dynamicPattern,
    (match) => dynamicValues.generate(match.group(1)!) ?? match.group(0)!,
  );
}

/// Interpolates the key and value of every enabled entry. Disabled entries
/// are returned unchanged -- interpolation is deferred until they're
/// actually going to be sent.
List<KeyValueEntry> interpolateEntries(
  List<KeyValueEntry> entries,
  Map<String, String> variables, {
  DynamicValues? dynamicValues,
}) {
  return entries
      .map(
        (entry) => entry.enabled
            ? entry.copyWith(
                key: interpolate(entry.key, variables, dynamicValues: dynamicValues),
                value: interpolate(entry.value, variables, dynamicValues: dynamicValues),
              )
            : entry,
      )
      .toList();
}

/// Interpolates a [RequestBody]: the raw string of a json body, or the
/// enabled fields of a formUrlEncoded body, and the name, value (text or file
/// path) and content type of the enabled fields of a multipart one. `none` is
/// returned unchanged.
RequestBody interpolateBody(
  RequestBody body,
  Map<String, String> variables, {
  DynamicValues? dynamicValues,
}) {
  return body.map(
    none: (b) => b,
    json: (b) => RequestBody.json(interpolate(b.raw, variables, dynamicValues: dynamicValues)),
    formUrlEncoded: (b) => RequestBody.formUrlEncoded(
      interpolateEntries(b.fields, variables, dynamicValues: dynamicValues),
    ),
    multipart: (b) => RequestBody.multipart([
      for (final field in b.fields)
        // A disabled field is not sent, so it is not resolved either.
        if (!field.enabled)
          field
        else
          field.copyWith(
            name: interpolate(field.name, variables, dynamicValues: dynamicValues),
            value: interpolate(field.value, variables, dynamicValues: dynamicValues),
            contentType: field.contentType == null
                ? null
                : interpolate(field.contentType!, variables, dynamicValues: dynamicValues),
          ),
    ]),
  );
}
