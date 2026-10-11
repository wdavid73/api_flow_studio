import '../../models/models.dart';
import '../import_result.dart';
import 'postman_json.dart';
import 'postman_variables.dart';

/// One Postman item that has a `request`, as an [Endpoint] with the given ids.
///
/// Reading is tolerant (a request may be just a URL string, a `url` text or an object,
/// a `header` a list or a block of text) and everything that cannot be carried over is
/// added to [warnings], located by [path] (`Auth / Login`). Variables in every text go
/// through [translator].
Endpoint requestToEndpoint({
  required Map<String, dynamic> item,
  required String id,
  required String groupId,
  required String path,
  required VariableTranslator translator,
  required List<ImportWarning> warnings,
}) {
  final unknown = <String>[];
  String t(String text) => translator.translate(text, unknownDynamic: unknown);

  final rawRequest = item['request'];
  final request = rawRequest is String ? <String, dynamic>{'url': rawRequest} : asMap(rawRequest) ?? const <String, dynamic>{};

  final methodText = (asString(request['method']) ?? '').trim().toUpperCase();
  final method = methodText.isEmpty ? 'GET' : methodText;

  final url = _readUrl(request['url'], path, t, warnings);
  final headers = _readHeaders(request['header'], t);

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
    headers: headers,
    queryParams: url.query,
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
