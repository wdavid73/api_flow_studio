import 'dart:convert';

import '../http/executed_response.dart';
import '../http/request_executor.dart';
import '../models/models.dart';
import 'session.dart';
import 'session_apply.dart';
import 'token_finder.dart';

/// Wraps a [RequestExecutor] with the login session: before sending it adds
/// the Bearer header and the `session_*` variables; after a 2xx JSON response
/// it stores any tokens found. The session is read and written through
/// closures so this stays free of any state-management framework.
class SessionRequestExecutor implements RequestExecutor {
  SessionRequestExecutor({
    required this._inner,
    required this._readSession,
    required this._writeSession,
    this.onTokensCaptured,
  });

  final RequestExecutor _inner;
  final Session Function() _readSession;
  final void Function(Session) _writeSession;

  /// Called after a response changed the stored tokens (never with their values).
  final void Function()? onTokensCaptured;

  @override
  Future<ExecutedResponse> execute(
    Endpoint endpoint, {
    required Map<String, String> variables,
  }) async {
    final session = _readSession();
    final sessionVars = sessionVariables(session);

    final response = await _inner.execute(
      applySession(endpoint, session),
      // Environment variables win over session variables of the same name.
      variables: sessionVars.isEmpty ? variables : {...sessionVars, ...variables},
    );

    _capture(response);
    return response;
  }

  void _capture(ExecutedResponse response) {
    final status = response.status;
    if (status == null || status < 200 || status >= 300) return;

    final current = _readSession();
    if (!current.captureTokens) return;

    final json = _asJson(response.body);
    if (json == null) return;

    final found = findTokens(json);
    final next = current.copyWith(
      accessToken: found.accessToken ?? current.accessToken,
      refreshToken: found.refreshToken ?? current.refreshToken,
    );
    if (next == current) return;

    _writeSession(next);
    onTokensCaptured?.call();
  }

  /// [body] as a decoded JSON container, or null if it is not one.
  Object? _asJson(Object? body) {
    if (body is Map || body is List) return body;
    if (body is String) {
      try {
        final decoded = jsonDecode(body);
        return decoded is Map || decoded is List ? decoded : null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
