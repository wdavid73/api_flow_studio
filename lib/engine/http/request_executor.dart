import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/models.dart';
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
  RequestExecutor({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<ExecutedResponse> execute(
    Endpoint endpoint, {
    required Map<String, String> variables,
  }) async {
    final url = interpolate(endpoint.url, variables);
    final headers = _resolveEnabled(
      interpolateEntries(endpoint.headers, variables),
    );
    final queryParams = _resolveEnabled(
      interpolateEntries(endpoint.queryParams, variables),
    );

    final resolvedBody = interpolateBody(endpoint.body, variables);
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
    _applyAuth(endpoint.authConfig, variables, headers);

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
      );
    } on DioException catch (e) {
      stopwatch.stop();
      return ExecutedResponse(
        elapsedMs: stopwatch.elapsedMilliseconds,
        error: e.message ?? e.toString(),
      );
    }
  }

  Map<String, String> _resolveEnabled(List<KeyValueEntry> entries) => {
        for (final entry in entries)
          if (entry.enabled) entry.key: entry.value,
      };

  void _applyAuth(
    AuthConfig auth,
    Map<String, String> variables,
    Map<String, String> headers,
  ) {
    auth.when(
      none: () {},
      basic: (username, password) {
        final resolvedUser = interpolate(username, variables);
        final resolvedPassword = interpolate(password, variables);
        final token = base64Encode(utf8.encode('$resolvedUser:$resolvedPassword'));
        headers['Authorization'] = 'Basic $token';
      },
      bearer: (token) {
        headers['Authorization'] = 'Bearer ${interpolate(token, variables)}';
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
