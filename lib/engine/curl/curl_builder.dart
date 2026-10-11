import 'dart:convert';

import '../models/models.dart';
import '../variables/interpolator.dart';

/// Builds a curl command for [endpoint], the inverse of `parseCurl`.
///
/// `{{variables}}` are resolved from [variables] the same way the request
/// executor does (unknown ones stay literal). Enabled query params are
/// appended to the URL, enabled headers become `-H` lines, auth becomes an
/// `Authorization` header, and a body becomes `--data` with the matching
/// `Content-Type` unless the endpoint already sets one. Parts are joined with
/// a backslash continuation so the result reads like "Copy as cURL" output.
String buildCurl(Endpoint endpoint, {Map<String, String> variables = const {}}) {
  final headers = <String, String>{
    for (final h in interpolateEntries(endpoint.headers, variables))
      if (h.enabled) h.key: h.value,
  };

  final (String? data, String? contentType) = interpolateBody(endpoint.body, variables).when(
    none: () => (null, null),
    multipart: (_) => (null, null), // written as --form lines below
    json: (raw) => (raw, 'application/json'),
    formUrlEncoded: (fields) => (
      [
        for (final f in fields)
          if (f.enabled) '${Uri.encodeComponent(f.key)}=${Uri.encodeComponent(f.value)}',
      ].join('&'),
      'application/x-www-form-urlencoded',
    ),
  );
  if (contentType != null && !headers.keys.any((k) => k.toLowerCase() == 'content-type')) {
    headers['Content-Type'] = contentType;
  }

  endpoint.authConfig.when(
    none: () {},
    basic: (username, password) {
      final token = base64Encode(utf8.encode(
        '${interpolate(username, variables)}:${interpolate(password, variables)}',
      ));
      headers['Authorization'] = 'Basic $token';
    },
    bearer: (token) => headers['Authorization'] = 'Bearer ${interpolate(token, variables)}',
  );

  final lines = ["curl -X ${endpoint.method} ${_quote(_urlWithQuery(endpoint, variables))}"];
  headers.forEach((key, value) => lines.add('  -H ${_quote('$key: $value')}'));
  if (data != null) lines.add('  --data ${_quote(data)}');
  // curl adds the Content-Type and boundary of a form on its own.
  interpolateBody(endpoint.body, variables).maybeMap(
    multipart: (b) {
      for (final field in b.fields.where((f) => f.enabled && f.name.isNotEmpty)) {
        lines.add(switch (field.kind) {
          MultipartFieldKind.text => '  --form-string ${_quote('${field.name}=${field.value}')}',
          MultipartFieldKind.file => '  -F ${_quote('${field.name}=@${_formFile(field)}')}',
        });
      }
    },
    orElse: () {},
  );
  return lines.join(' \\\n');
}

String _urlWithQuery(Endpoint endpoint, Map<String, String> variables) {
  final url = interpolate(endpoint.url, variables);
  final query = [
    for (final p in interpolateEntries(endpoint.queryParams, variables))
      if (p.enabled) '${Uri.encodeComponent(p.key)}=${Uri.encodeComponent(p.value)}',
  ].join('&');
  if (query.isEmpty) return url;
  return '$url${url.contains('?') ? '&' : '?'}$query';
}

/// The part of a `-F name=@...` value after the `@`: the path, double-quoted when
/// curl would otherwise read a `;`, `,`, quote or space in it as syntax, then
/// `;type=...` when the field has an explicit content type.
String _formFile(MultipartField field) {
  final needsQuotes = RegExp(r'[;,"\s]').hasMatch(field.value);
  final path = needsQuotes ? '"${field.value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"' : field.value;
  final type = field.contentType;
  return type == null || type.isEmpty ? path : '$path;type=$type';
}

/// Wraps [value] in single quotes, escaping embedded single quotes as `'\''`.
String _quote(String value) => "'${value.replaceAll("'", r"'\''")}'";
