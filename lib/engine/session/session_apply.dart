import '../models/models.dart';
import 'session.dart';

/// Names an environment variable can have to act as the access token when the
/// session has none (checked in this order).
const accessTokenVariableNames = ['access_token', 'accessToken'];

/// The access token an environment defines in [variables] (blank counts as none).
String? accessTokenFromVariables(Map<String, String> variables) {
  for (final name in accessTokenVariableNames) {
    final value = variables[name]?.trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

/// [endpoint] carrying the Bearer token, or [endpoint] itself (same instance)
/// when nothing should be attached.
///
/// The token is the session's; when the session has none, [fallbackToken] (an
/// `access_token` variable of the environment) is used instead, so a token pasted
/// into the environment works the same as one captured from a login.
///
/// Nothing is attached when [Session.attachAuth] is off, there is no token,
/// the request already has an [AuthConfig], or it already has an enabled
/// `Authorization` header: what a request says explicitly always wins.
Endpoint applySession(Endpoint endpoint, Session session, {String? fallbackToken}) {
  if (!session.attachAuth) return endpoint;
  final token = session.hasToken ? session.accessToken.trim() : fallbackToken?.trim();
  if (token == null || token.isEmpty) return endpoint;
  if (!acceptsSessionToken(endpoint)) return endpoint;

  return endpoint.copyWith(headers: [
    ...endpoint.headers,
    KeyValueEntry(key: 'Authorization', value: 'Bearer $token'),
  ]);
}

/// Whether [endpoint] would take the session's token: it has no
/// authentication of its own and no enabled `Authorization` header. What a
/// request says explicitly always wins over the session.
bool acceptsSessionToken(Endpoint endpoint) {
  if (endpoint.authConfig is! AuthConfigNone) return false;
  return !endpoint.headers.any((h) => h.enabled && h.key.trim().toLowerCase() == 'authorization');
}
