import 'dart:convert';

import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/variables/interpolator.dart';

/// One request as the (fake) server received it: what the real executor would
/// have put on the wire, with `{{variables}}` resolved and the session's
/// `Authorization` already attached.
class RecordedCall {
  const RecordedCall({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
    required this.variables,
  });

  final String method;
  final String url;
  final Map<String, String> headers;
  final String? body;

  /// The variable map the executor was given (environment plus session ones).
  final Map<String, String> variables;

  Uri get uri => Uri.parse(url);

  /// The value of header [name] (any capitalization), or null.
  String? header(String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
    }
    return null;
  }
}

/// Answers a [RecordedCall] with the response the fake server should give.
typedef FakeRoute = ExecutedResponse Function(RecordedCall call);

/// A scripted stand-in for the HTTP layer. It sits where the real
/// `RequestExecutor` does, so everything in front of it (session, variables,
/// history, flows) is the real thing. It resolves variables the same way the
/// real executor does, logs every call and answers by `"METHOD /path"`.
class FakeBackend implements RequestExecutor {
  FakeBackend({Map<String, FakeRoute> routes = const {}}) : routes = {..._demoRoutes(), ...routes};

  /// Routes by `"GET /items"`; anything not listed answers `200 {}`. The demo
  /// routes are there from the start and a route given to the constructor
  /// replaces the demo one with the same key.
  final Map<String, FakeRoute> routes;

  /// Every call received, oldest first.
  final List<RecordedCall> calls = [];

  RecordedCall get lastCall => calls.last;

  @override
  Future<ExecutedResponse> execute(
    Endpoint endpoint, {
    required Map<String, String> variables,
  }) async {
    final headers = {
      for (final h in interpolateEntries(endpoint.headers, variables))
        if (h.enabled) h.key: h.value,
    };
    final body = interpolateBody(endpoint.body, variables).when(
      none: () => null,
      json: (raw) => raw,
      formUrlEncoded: (fields) => [for (final f in fields) if (f.enabled) '${f.key}=${f.value}'].join('&'),
    );

    final call = RecordedCall(
      method: endpoint.method,
      url: interpolate(endpoint.url, variables),
      headers: headers,
      body: body,
      variables: variables,
    );
    calls.add(call);

    final route = routes['${call.method} ${call.uri.path}'];
    return route != null ? route(call) : json(const {});
  }
}

/// A `200` response with [body] as its JSON body.
ExecutedResponse json(Object? body, {int status = 200}) => ExecutedResponse(
      status: status,
      headers: const {'content-type': 'application/json'},
      body: body,
      elapsedMs: 5,
      sizeBytes: utf8.encode(jsonEncode(body)).length,
    );

/// The routes every journey can rely on.
Map<String, FakeRoute> _demoRoutes() => {
      'GET /items': (_) => json({
            'items': [
              {'id': 1, 'name': 'Apple'},
              {'id': 2, 'name': 'Pear'},
            ],
          }),
      'GET /boom': (_) => const ExecutedResponse(error: 'Connection refused', elapsedMs: 3),
      'GET /flaky': (_) => json({'error': 'server exploded'}, status: 500),
    };
