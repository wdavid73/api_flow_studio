import '../../models/models.dart';
import '../import_json.dart';
import '../import_result.dart';
import 'openapi_body.dart';
import 'openapi_context.dart';
import 'openapi_security.dart';

/// Headers OpenAPI says a header parameter must not set (the body and the
/// authentication have their own place).
const Set<String> _reservedHeaders = {'accept', 'content-type', 'authorization'};

final RegExp _pathToken = RegExp(r'\{([^{}]+)\}');

/// One operation as an [Endpoint]: name, method, URL (`{{base_url}}` and `{{param}}`),
/// query parameters, headers, body and authentication. What cannot be carried over is added to
/// `context.warnings`, located as `METHOD /path`.
Endpoint operationToEndpoint({
  required String path,
  required String method,
  required Map<String, dynamic> operation,
  required List<dynamic> pathParameters,
  required OpenApiContext context,
  required String id,
  required String groupId,
}) {
  final where = '${method.toUpperCase()} $path';
  final query = <KeyValueEntry>[];
  final headers = <KeyValueEntry>[];

  for (final parameter in _merged(pathParameters, asList(operation['parameters']), context, where)) {
    final name = asString(parameter['name'])!;
    switch (asString(parameter['in'])) {
      case 'path':
        final given = _given(parameter, context, where);
        context.defineVariable(context.names.sanitize(name), given.found ? _text(given.value) : '');
      case 'query':
        query.addAll(_rows(parameter, name, context, where, isHeader: false));
      case 'header':
        if (!_reservedHeaders.contains(name.toLowerCase())) headers.addAll(_rows(parameter, name, context, where, isHeader: true));
      case 'cookie':
        context.warnings.add(ImportWarning(where: where, message: 'cookie parameter "$name" was not imported'));
    }
  }

  // `{param}` in the path, declared or not, is a variable of the environment.
  final url = '{{base_url}}${path.replaceAllMapped(_pathToken, (match) {
    final variable = context.names.sanitize(match[1]!);
    context.defineVariable(variable, '');
    return '{{$variable}}';
  })}';

  final body = readRequestBody(operation: operation, context: context, where: where, headers: headers);
  final auth = readSecurity(operation: operation, context: context, where: where);

  final summary = (asString(operation['summary']) ?? '').trim();
  final operationId = (asString(operation['operationId']) ?? '').trim();
  final description = (asString(operation['description']) ?? '').trim();
  return Endpoint(
    id: id,
    groupId: groupId,
    name: summary.isNotEmpty ? summary : (operationId.isNotEmpty ? operationId : where),
    method: method.toUpperCase(),
    url: url,
    description: description.isNotEmpty ? description : summary,
    headers: [...headers, ...body.extraHeaders, ?auth.header],
    queryParams: [...query, ?auth.query],
    body: body.body,
    authConfig: auth.config,
  );
}

/// The parameters of the path and of the operation, the operation's replacing a path one
/// with the same name and place; references followed, rows that are not parameters dropped.
List<Map<String, dynamic>> _merged(List<dynamic> fromPath, List<dynamic> fromOperation, OpenApiContext context, String where) {
  final byKey = <String, Map<String, dynamic>>{};
  for (final raw in [...fromPath, ...fromOperation]) {
    final parameter = context.refs.resolve(raw, where: where);
    final name = parameter == null ? null : asString(parameter['name']);
    final place = parameter == null ? null : asString(parameter['in']);
    if (parameter == null || name == null || name.isEmpty || place == null) continue;
    byKey['$place:$name'] = parameter;
  }
  return byKey.values.toList();
}

/// A value the file gives a parameter: its `example`, the first of its `examples`, or
/// what its schema gives (`default`, `enum`…).
({bool found, Object? value}) _given(Map<String, dynamic> parameter, OpenApiContext context, String where) {
  if (parameter.containsKey('example')) {
    return (found: true, value: context.sampler.plainExample(parameter['example'], where: where));
  }
  final examples = asMap(parameter['examples']);
  if (examples != null && examples.isNotEmpty) {
    final first = context.refs.resolve(examples.values.first, where: where);
    if (first != null && first.containsKey('value')) {
      return (found: true, value: context.sampler.plainExample(first['value'], where: where));
    }
  }
  return context.sampler.given(parameter['schema'], where: where);
}

/// The text of a scalar value (null is empty).
String _text(Object? value) => value == null ? '' : '$value';

/// The rows a query or header parameter becomes. A required parameter is on; an optional
/// one is off, so the request works as it is. A required one with no value to be had is
/// `{{name}}`, defined (empty) in the environment, rather than an invented value.
List<KeyValueEntry> _rows(Map<String, dynamic> parameter, String name, OpenApiContext context, String where, {required bool isHeader}) {
  final required = parameter['required'] == true;
  final given = _given(parameter, context, where);

  final schema = context.refs.resolve(parameter['schema'], where: where);
  final isObject = (given.found && given.value is Map) || (!given.found && schema?['type'] == 'object') || parameter['style'] == 'deepObject';
  if (isObject) {
    context.warnings.add(ImportWarning(where: where, message: 'parameter "$name" is an object and was not imported'));
    return const [];
  }

  if (!given.found) {
    if (!required) return [KeyValueEntry(key: name, value: '', enabled: false)];
    final variable = context.names.sanitize(name);
    context.defineVariable(variable, '');
    return [KeyValueEntry(key: name, value: '{{$variable}}')];
  }

  final value = given.value;
  if (value is List) {
    final style = asString(parameter['style']) ?? 'form';
    final explode = parameter.containsKey('explode') ? parameter['explode'] == true : style == 'form';
    if (explode && !isHeader && value.isNotEmpty) {
      return [for (final item in value) KeyValueEntry(key: name, value: _text(item), enabled: required)];
    }
    final separator = switch (style) {
      'spaceDelimited' => ' ',
      'pipeDelimited' => '|',
      _ => ',',
    };
    return [KeyValueEntry(key: name, value: value.map(_text).join(separator), enabled: required)];
  }
  return [KeyValueEntry(key: name, value: _text(value), enabled: required)];
}
