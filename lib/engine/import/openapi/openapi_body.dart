import 'dart:convert';

import '../../models/models.dart';
import '../import_json.dart';
import '../import_result.dart';
import 'openapi_context.dart';

typedef OpenApiBody = ({RequestBody body, List<KeyValueEntry> extraHeaders});

const OpenApiBody _noBody = (body: RequestBody.none(), extraHeaders: <KeyValueEntry>[]);

/// What `requestBody` of [operation] becomes. One media type is chosen (JSON, then a form,
/// then multipart, then text); the others are other ways of saying the same thing, so
/// leaving them out is not worth a warning. A `Content-Type` is added only for a body the
/// JSON editor would otherwise send as JSON, and only when the request has none already.
OpenApiBody readRequestBody({
  required Map<String, dynamic> operation,
  required OpenApiContext context,
  required String where,
  required List<KeyValueEntry> headers,
}) {
  final requestBody = context.refs.resolve(operation['requestBody'], where: where);
  final content = requestBody == null ? null : asMap(requestBody['content']);
  if (content == null || content.isEmpty) return _noBody;

  String? chosen;
  var best = _unsupported;
  for (final type in content.keys) {
    final rank = _rank(_mediaType(type));
    if (rank < best) {
      best = rank;
      chosen = type;
    }
  }
  if (chosen == null) {
    context.warnings.add(ImportWarning(where: where, message: 'binary request body is not supported; the body was left empty'));
    return _noBody;
  }

  final media = context.refs.resolve(content[chosen], where: where) ?? const <String, dynamic>{};
  final type = _mediaType(chosen);
  return switch (best) {
    _jsonRank || _plusJsonRank => _json(media, type, context, where, headers),
    _formRank => (body: RequestBody.formUrlEncoded(_formRows(media, context, where)), extraHeaders: const <KeyValueEntry>[]),
    _multipartRank => (body: RequestBody.multipart(_multipartFields(media, context, where)), extraHeaders: const <KeyValueEntry>[]),
    _ => _text(media, type, context, where, headers),
  };
}

const int _jsonRank = 0;
const int _plusJsonRank = 1;
const int _formRank = 2;
const int _multipartRank = 3;
const int _textRank = 4;
const int _unsupported = 5;

/// The media type without its parameters (`application/json; charset=utf-8`), lower-cased.
String _mediaType(String type) => type.split(';').first.trim().toLowerCase();

int _rank(String type) {
  if (type == 'application/json') return _jsonRank;
  if (type.endsWith('+json')) return _plusJsonRank;
  if (type == 'application/x-www-form-urlencoded') return _formRank;
  if (type == 'multipart/form-data') return _multipartRank;
  if (type.startsWith('text/') || type.endsWith('xml')) return _textRank;
  return _unsupported;
}

bool _hasContentType(List<KeyValueEntry> headers) => headers.any((h) => h.key.toLowerCase() == 'content-type');

/// An example the media type itself gives: `example`, or the first of `examples`.
({bool found, Object? value}) _explicit(Map<String, dynamic> media, OpenApiContext context, String where) {
  if (media.containsKey('example')) return (found: true, value: context.sampler.plainExample(media['example'], where: where));
  final examples = asMap(media['examples']);
  if (examples != null && examples.isNotEmpty) {
    final first = context.refs.resolve(examples.values.first, where: where);
    if (first != null && first.containsKey('value')) {
      return (found: true, value: context.sampler.plainExample(first['value'], where: where));
    }
  }
  return (found: false, value: null);
}

OpenApiBody _json(Map<String, dynamic> media, String type, OpenApiContext context, String where, List<KeyValueEntry> headers) {
  final explicit = _explicit(media, context, where);
  Object? value = explicit.value;
  if (!explicit.found) {
    value = context.sampler.sample(media['schema'], where: where);
    if (value == null) return _noBody;
  }

  final extra = type != 'application/json' && !_hasContentType(headers) ? [KeyValueEntry(key: 'Content-Type', value: type)] : const <KeyValueEntry>[];
  return (body: RequestBody.json(const JsonEncoder.withIndent('  ').convert(value)), extraHeaders: extra);
}

OpenApiBody _text(Map<String, dynamic> media, String type, OpenApiContext context, String where, List<KeyValueEntry> headers) {
  var found = _explicit(media, context, where);
  if (!found.found) found = context.sampler.given(media['schema'], where: where);

  if (!found.found || found.value == null) {
    context.warnings.add(ImportWarning(where: where, message: 'the "$type" body has no example; left empty'));
    return _noBody;
  }
  final value = found.value;
  final text = value is String ? value : jsonEncode(value);
  context.warnings.add(ImportWarning(where: where, message: 'request body in "$type" imported as text with Content-Type $type'));
  return (
    body: RequestBody.json(text),
    extraHeaders: _hasContentType(headers) ? const <KeyValueEntry>[] : [KeyValueEntry(key: 'Content-Type', value: type)],
  );
}

/// The properties and required names of an object schema, with those of its `allOf` parts.
({Map<String, dynamic> properties, Set<String> required}) _shape(Object? schema, OpenApiContext context, String where, [int depth = 0]) {
  final resolved = context.refs.resolve(schema, where: where);
  final properties = <String, dynamic>{...?asMap(resolved?['properties'])};
  final required = <String>{...asList(resolved?['required']).whereType<String>()};
  if (resolved != null && depth < 3) {
    for (final part in asList(resolved['allOf'])) {
      final inner = _shape(part, context, where, depth + 1);
      properties.addAll(inner.properties);
      required.addAll(inner.required);
    }
  }
  return (properties: properties, required: required);
}

/// The text a value takes in a form field: scalars as they are, structures as JSON.
String _fieldText(Object? value) => value == null ? '' : (value is Map || value is List ? jsonEncode(value) : '$value');

List<KeyValueEntry> _formRows(Map<String, dynamic> media, OpenApiContext context, String where) {
  final shape = _shape(media['schema'], context, where);
  final rows = <KeyValueEntry>[];

  for (final entry in shape.properties.entries) {
    final name = entry.key;
    if (context.refs.resolve(entry.value, where: where)?['readOnly'] == true) continue;
    final required = shape.required.contains(name);
    final given = context.sampler.given(entry.value, where: where);

    if (!given.found) {
      if (!required) {
        rows.add(KeyValueEntry(key: name, value: '', enabled: false));
      } else {
        final variable = context.names.sanitize(name);
        context.defineVariable(variable, '');
        rows.add(KeyValueEntry(key: name, value: '{{$variable}}'));
      }
    } else if (given.value is List) {
      final items = given.value as List;
      if (items.isEmpty) rows.add(KeyValueEntry(key: name, value: '', enabled: required));
      for (final item in items) {
        rows.add(KeyValueEntry(key: name, value: _fieldText(item), enabled: required));
      }
    } else {
      rows.add(KeyValueEntry(key: name, value: _fieldText(given.value), enabled: required));
    }
  }
  return rows;
}

/// Whether a property holds a file: binary text, or a media type the schema names.
bool _isFile(Map<String, dynamic>? schema, OpenApiContext context, String where) {
  if (schema == null) return false;
  if (schema['type'] == 'string' && (schema['format'] == 'binary' || schema['contentMediaType'] is String)) return true;
  if (schema['type'] == 'array') {
    final items = context.refs.resolve(schema['items'], where: where);
    return items != null && items['type'] == 'string' && (items['format'] == 'binary' || items['contentMediaType'] is String);
  }
  return false;
}

List<MultipartField> _multipartFields(Map<String, dynamic> media, OpenApiContext context, String where) {
  final shape = _shape(media['schema'], context, where);
  final encoding = asMap(media['encoding']) ?? const <String, dynamic>{};
  final fields = <MultipartField>[];

  for (final entry in shape.properties.entries) {
    final name = entry.key;
    final schema = context.refs.resolve(entry.value, where: where);
    if (schema?['readOnly'] == true) continue;
    final required = shape.required.contains(name);

    if (_isFile(schema, context, where)) {
      final contentType = asString(asMap(encoding[name])?['contentType'])?.split(',').first.trim();
      fields.add(MultipartField(
        name: name,
        kind: MultipartFieldKind.file,
        contentType: contentType == null || contentType.isEmpty ? null : contentType,
        enabled: required,
      ));
      if (required) context.warnings.add(ImportWarning(where: where, message: 'file field "$name" needs a file chosen'));
      continue;
    }

    final given = context.sampler.given(entry.value, where: where);
    if (given.found) {
      fields.add(MultipartField(name: name, value: _fieldText(given.value), enabled: required));
    } else if (required) {
      final variable = context.names.sanitize(name);
      context.defineVariable(variable, '');
      fields.add(MultipartField(name: name, value: '{{$variable}}'));
    } else {
      fields.add(MultipartField(name: name, enabled: false));
    }
  }
  return fields;
}
