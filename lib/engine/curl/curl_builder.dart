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

/// Wraps [value] in single quotes, escaping embedded single quotes as `'\''`.
String _quote(String value) => "'${value.replaceAll("'", r"'\''")}'";
