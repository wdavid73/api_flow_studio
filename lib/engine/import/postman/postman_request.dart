import 'dart:convert';

import '../../models/models.dart';
import '../import_result.dart';
import 'postman_auth.dart';
import '../import_json.dart';
import 'postman_variables.dart';

/// One Postman item that has a `request`, as an [Endpoint] with the given ids.
///
/// Reading is tolerant (a request may be just a URL string, a `url` text or an object,
/// a `header` a list or a block of text) and everything that cannot be carried over is
/// added to [warnings], located by [path] (`Auth / Login`). Variables in every text go
/// through [translator]. [auth] is what the request resolved to (its own, or inherited).
Endpoint requestToEndpoint({
  required Map<String, dynamic> item,
  required String id,
  required String groupId,
  required String path,
  required VariableTranslator translator,
  required List<ImportWarning> warnings,
  PostmanAuth auth = PostmanAuth.none,
}) {
  final unknown = <String>[];
  String t(String text) => translator.translate(text, unknownDynamic: unknown);

  final rawRequest = item['request'];
  final request = rawRequest is String ? <String, dynamic>{'url': rawRequest} : asMap(rawRequest) ?? const <String, dynamic>{};

  final methodText = (asString(request['method']) ?? '').trim().toUpperCase();
  final method = methodText.isEmpty ? 'GET' : methodText;

  final url = _readUrl(request['url'], path, t, warnings);
  final headers = _readHeaders(request['header'], t);
  final body = _readBody(request['body'], headers, path, t, warnings);

  final name = (asString(item['name']) ?? '').trim();
  final description = textOf(request['description']).isNotEmpty ? textOf(request['description']) : textOf(item['description']);

  warnings.addAll(unknownDynamicWarnings(path, unknown));
  return Endpoint(
    id: id,
    groupId: groupId,
    name: name.isEmpty ? '$method ${url.base}' : name,
    method: method,
    url: url.base,
    description: description,
    headers: [...headers, ...body.extraHeaders, ?auth.header],
    queryParams: [...url.query, ?auth.queryParam],
    body: body.body,
    authConfig: auth.config,
  );
}

typedef _Translate = String Function(String text);

/// A `/:name` path segment (a colon after a slash, so `localhost:3000` never matches).
final RegExp _pathVariable = RegExp(r'(?<=/):([A-Za-z_][\w-]*)(?=/|$)');

({String base, List<KeyValueEntry> query}) _readUrl(Object? url, String path, _Translate t, List<ImportWarning> warnings) {
  final map = asMap(url);
  final String text;
  List<dynamic>? queryList;
  final pathValues = <String, String>{};

  if (url is String) {
    text = url;
  } else if (map != null) {
    final raw = asString(map['raw']);
    text = raw != null && raw.isNotEmpty ? raw : _fromParts(map);
    if (map['query'] is List) queryList = map['query'] as List;
    for (final variable in asList(map['variable'])) {
      final entry = asMap(variable);
      final key = entry == null ? null : asString(entry['key']);
      if (key != null) pathValues[key] = entry!['value'] == null ? '' : '${entry['value']}';
    }
  } else {
    return (base: '', query: const []);
  }

  final cut = text.indexOf('?');
  final baseText = cut == -1 ? text : text.substring(0, cut);
  final queryText = cut == -1 ? '' : text.substring(cut + 1);

  final warned = <String>{};
  final base = baseText.replaceAllMapped(_pathVariable, (match) {
    final name = match[1]!;
    final value = pathValues[name] ?? '';
    if (value.isNotEmpty) return value;
    if (warned.add(name)) {
      warnings.add(ImportWarning(where: path, message: 'path variable :$name has no value; written as {{$name}}'));
    }
    return '{{$name}}';
  });

  final query = queryList != null ? _queryFromList(queryList, t) : _queryFromText(queryText, t);
  return (base: t(base), query: query);
}

/// `protocol://host.parts[:port]/path/parts` from the pieces of a `url` object.
String _fromParts(Map<String, dynamic> url) {
  String join(Object? value, String separator) => value is List ? value.whereType<String>().join(separator) : asString(value) ?? '';

  final protocol = asString(url['protocol']) ?? '';
  final host = join(url['host'], '.');
  final port = url['port'] == null ? '' : ':${url['port']}';
  final path = join(url['path'], '/');
  return '${protocol.isEmpty ? '' : '$protocol://'}$host$port${path.isEmpty ? '' : '/$path'}';
}

List<KeyValueEntry> _queryFromList(List<dynamic> list, _Translate t) {
  final entries = <KeyValueEntry>[];
  for (final item in list) {
    final map = asMap(item);
    if (map == null) continue;
    final key = asString(map['key']) ?? '';
    final value = map['value'] == null ? '' : '${map['value']}';
    if (key.isEmpty && value.isEmpty) continue;
    entries.add(KeyValueEntry(key: t(key), value: t(value), enabled: map['disabled'] != true));
  }
  return entries;
}

List<KeyValueEntry> _queryFromText(String query, _Translate t) {
  return [
    for (final pair in query.split('&'))
      if (pair.isNotEmpty)
        () {
          final cut = pair.indexOf('=');
          final key = cut == -1 ? pair : pair.substring(0, cut);
          final value = cut == -1 ? '' : pair.substring(cut + 1);
          return KeyValueEntry(key: t(_decode(key)), value: t(_decode(value)));
        }(),
  ];
}

/// The text a URL's percent-encoding stands for (dio encodes the params again when sending).
String _decode(String text) {
  try {
    return Uri.decodeQueryComponent(text);
  } on ArgumentError {
    return text;
  }
}

List<KeyValueEntry> _readHeaders(Object? header, _Translate t) {
  if (header is String) {
    return [
      for (final line in header.split(RegExp(r'\r?\n')))
        if (line.contains(':') && line.substring(0, line.indexOf(':')).trim().isNotEmpty)
          KeyValueEntry(key: t(line.substring(0, line.indexOf(':')).trim()), value: t(line.substring(line.indexOf(':') + 1).trim())),
    ];
  }

  final headers = <KeyValueEntry>[];
  for (final item in asList(header)) {
    final map = asMap(item);
    final key = map == null ? null : asString(map['key'])?.trim();
    if (map == null || key == null || key.isEmpty) continue;
    headers.add(KeyValueEntry(
      key: t(key),
      value: t(map['value'] == null ? '' : '${map['value']}'),
      enabled: map['disabled'] != true,
    ));
  }
  return headers;
}

typedef _Body = ({RequestBody body, List<KeyValueEntry> extraHeaders});

const _Body _noBody = (body: RequestBody.none(), extraHeaders: <KeyValueEntry>[]);

/// What `request.body` becomes. A `Content-Type` is added only for a raw body that the
/// JSON editor would otherwise send as JSON, and only when the request has none of its
/// own (enabled or not).
_Body _readBody(Object? value, List<KeyValueEntry> headers, String path, _Translate t, List<ImportWarning> warnings) {
  final body = asMap(value);
  if (body == null) return _noBody;

  void warn(String message) => warnings.add(ImportWarning(where: path, message: message));

  final mode = asString(body['mode']);
  if (mode == null || mode.isEmpty) return _noBody;
  if (body['disabled'] == true) {
    warn('the body is disabled in Postman; left empty');
    return _noBody;
  }

  switch (mode) {
    case 'raw':
      return _readRaw(body, headers, t, warn);
    case 'urlencoded':
      return (
        body: RequestBody.formUrlEncoded([
          for (final entry in asList(body['urlencoded']))
            ?_entry(entry, t),
        ]),
        extraHeaders: const <KeyValueEntry>[],
      );
    case 'formdata':
      return (body: RequestBody.multipart(_readFormData(body['formdata'], t, warn)), extraHeaders: const <KeyValueEntry>[]);
    case 'graphql':
      return (body: _readGraphql(asMap(body['graphql']), t, warn), extraHeaders: const <KeyValueEntry>[]);
    case 'file':
      warn('binary (file) body is not supported; the body was left empty');
      return _noBody;
    default:
      warn('body mode "$mode" is not supported; the body was left empty');
      return _noBody;
  }
}

/// A `{key, value, disabled}` row, or null when it has no key.
KeyValueEntry? _entry(Object? value, _Translate t) {
  final map = asMap(value);
  final key = map == null ? null : asString(map['key']);
  if (map == null || key == null || key.isEmpty) return null;
  return KeyValueEntry(key: t(key), value: t(map['value'] == null ? '' : '${map['value']}'), enabled: map['disabled'] != true);
}

_Body _readRaw(Map<String, dynamic> body, List<KeyValueEntry> headers, _Translate t, void Function(String) warn) {
  final text = t(asString(body['raw']) ?? '');
  if (text.trim().isEmpty) return _noBody;

  final language = (asString(asMap(asMap(body['options'])?['raw'])?['language']) ?? '').toLowerCase();
  final isJson = language == 'json' || ((language.isEmpty || language == 'text') && _looksLikeJson(text));
  if (isJson) return (body: RequestBody.json(text), extraHeaders: const <KeyValueEntry>[]);

  const types = {
    'xml': 'application/xml',
    'html': 'text/html',
    'javascript': 'application/javascript',
  };
  final type = types[language] ?? 'text/plain';
  final label = language.isEmpty ? 'text' : language;
  final hasOwnType = headers.any((h) => h.key.toLowerCase() == 'content-type');
  if (hasOwnType) {
    warn('raw body in "$label" imported as text (the request\'s own Content-Type is kept)');
    return (body: RequestBody.json(text), extraHeaders: const <KeyValueEntry>[]);
  }
  warn('raw body in "$label" imported as text with Content-Type $type');
  return (body: RequestBody.json(text), extraHeaders: [KeyValueEntry(key: 'Content-Type', value: type)]);
}

/// Whether [text] is a JSON object or array, with `{{variables}}` counted as values.
bool _looksLikeJson(String text) {
  try {
    final decoded = jsonDecode(text.replaceAll(RegExp(r'\{\{[^{}]+\}\}'), '0'));
    return decoded is Map || decoded is List;
  } on FormatException {
    return false;
  }
}

/// The parts of a `formdata` body. A file part keeps its name and content type but
/// never its `src`: a path in someone else's file is not a file you chose to send.
List<MultipartField> _readFormData(Object? value, _Translate t, void Function(String) warn) {
  final fields = <MultipartField>[];
  for (final entry in asList(value)) {
    final map = asMap(entry);
    final key = map == null ? null : asString(map['key']);
    if (map == null || key == null || key.isEmpty) continue;

    final name = t(key);
    final enabled = map['disabled'] != true;
    if (map['type'] == 'file') {
      fields.add(MultipartField(name: name, kind: MultipartFieldKind.file, contentType: asString(map['contentType']), enabled: enabled));
      if (enabled) warn('file field "$name" needs a file chosen');
    } else {
      fields.add(MultipartField(name: name, value: t(map['value'] == null ? '' : '${map['value']}'), enabled: enabled));
    }
  }
  return fields;
}

/// `{query, variables}` as the JSON body GraphQL servers expect.
RequestBody _readGraphql(Map<String, dynamic>? graphql, _Translate t, void Function(String) warn) {
  final query = t(asString(graphql?['query']) ?? '');
  final variablesText = (asString(graphql?['variables']) ?? '').trim();

  Object? variables = <String, Object?>{};
  if (variablesText.isNotEmpty) {
    try {
      final decoded = jsonDecode(t(variablesText));
      if (decoded is Map) {
        variables = decoded;
      } else {
        throw const FormatException('not an object');
      }
    } on FormatException {
      warn('graphql variables are not valid JSON; sent as {}');
    }
  }
  return RequestBody.json(const JsonEncoder.withIndent('  ').convert({'query': query, 'variables': variables}));
}
