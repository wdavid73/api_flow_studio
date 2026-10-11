import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/models.dart';
import '../variables/dynamic_values.dart';
import '../variables/interpolator.dart';
import 'executed_response.dart';

/// Sends an [Endpoint] over real HTTP using `dio`, after resolving its
/// `{{variable}}` tokens. This is the single entrypoint used both by the
/// manual request builder UI and by `flow_runner`, one call per step.
///
/// `dio` is configured with `validateStatus: (_) => true` so a 4xx/5xx
/// response comes back as a normal [ExecutedResponse] (matching real
/// Postman-like semantics -- a flow step expecting a 404 must not be
/// treated as a crash). Only transport-level failures (timeout, DNS,
/// connection refused) populate [ExecutedResponse.error] and leave
/// [ExecutedResponse.status] null.
class RequestExecutor {
  RequestExecutor({Dio? dio, DynamicValues? dynamicValues})
      : _dio = dio ?? Dio(),
        _dynamicValues = dynamicValues ?? DynamicValues();

  final Dio _dio;

  /// Fills the `{{$uuid}}`-style tokens; they exist only here, at send time.
  final DynamicValues _dynamicValues;

  Future<ExecutedResponse> execute(
    Endpoint endpoint, {
    required Map<String, String> variables,
  }) async {
    // Every `{{variable}}` and `{{$token}}` is resolved here, once per send.
    String text(String template) => interpolate(template, variables, dynamicValues: _dynamicValues);
    List<KeyValueEntry> entries(List<KeyValueEntry> list) =>
        interpolateEntries(list, variables, dynamicValues: _dynamicValues);

    final url = text(endpoint.url);
    final headers = _resolveEnabled(entries(endpoint.headers));
    final queryParams = _resolveEnabled(entries(endpoint.queryParams));

    final resolvedBody = interpolateBody(endpoint.body, variables, dynamicValues: _dynamicValues);
    final (Object? data, String? contentType) = resolvedBody.when(
      none: () => (null, null),
      json: (raw) => (raw, 'application/json'),
      formUrlEncoded: (fields) => (
        _resolveEnabled(fields),
        'application/x-www-form-urlencoded',
      ),
    );
    if (contentType != null) {
      headers.putIfAbsent('Content-Type', () => contentType);
    }
    _applyAuth(endpoint.authConfig, text, headers);

    final sentUrl = _withQuery(url, queryParams);

    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.request<dynamic>(
        url,
        data: data,
        queryParameters: queryParams.isEmpty ? null : queryParams,
        options: Options(
          method: endpoint.method,
          headers: headers,
          validateStatus: (_) => true,
        ),
      );
      stopwatch.stop();

      return ExecutedResponse(
        status: response.statusCode,
        headers: response.headers.map.map(
          (key, values) => MapEntry(key, values.join(', ')),
        ),
        body: response.data,
        elapsedMs: stopwatch.elapsedMilliseconds,
        sizeBytes: _sizeOf(response.data),
        requestUrl: sentUrl,
      );
    } on DioException catch (e) {
      stopwatch.stop();
      return ExecutedResponse(
        elapsedMs: stopwatch.elapsedMilliseconds,
        error: e.message ?? e.toString(),
        requestUrl: sentUrl,
      );
    }
  }

  /// [url] with [params] appended the way dio does it, so what the UI shows as
  /// "sent" includes the Params tab. [url] is not parsed: it may still hold an
  /// unresolved `{{variable}}`, which is not a valid URI.
  String _withQuery(String url, Map<String, String> params) {
    if (params.isEmpty) return url;
    final query = Uri(queryParameters: params).query;
    return '$url${url.contains('?') ? '&' : '?'}$query';
  }

  Map<String, String> _resolveEnabled(List<KeyValueEntry> entries) => {
        for (final entry in entries)
          if (entry.enabled) entry.key: entry.value,
      };

  void _applyAuth(
    AuthConfig auth,
    String Function(String) text,
    Map<String, String> headers,
  ) {
    auth.when(
      none: () {},
      basic: (username, password) {
        final token = base64Encode(utf8.encode('${text(username)}:${text(password)}'));
        headers['Authorization'] = 'Basic $token';
      },
      bearer: (token) {
        headers['Authorization'] = 'Bearer ${text(token)}';
      },
    );
  }

  int _sizeOf(dynamic data) {
    if (data == null) return 0;
    if (data is String) return utf8.encode(data).length;
    try {
      return utf8.encode(jsonEncode(data)).length;
    } catch (_) {
      return data.toString().length;
    }
  }
}
