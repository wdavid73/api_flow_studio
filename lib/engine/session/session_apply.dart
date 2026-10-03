import '../models/models.dart';
import 'session.dart';

/// [endpoint] carrying the session's Bearer token, or [endpoint] itself (same
/// instance) when nothing should be attached.
///
/// Nothing is attached when [Session.attachAuth] is off, there is no access
/// token, the request already has an [AuthConfig], or it already has an enabled
/// `Authorization` header: what a request says explicitly always wins.
Endpoint applySession(Endpoint endpoint, Session session) {
  if (!session.attachAuth || !session.hasToken) return endpoint;
  if (endpoint.authConfig is! AuthConfigNone) return endpoint;
  final hasAuthorizationHeader =
      endpoint.headers.any((h) => h.enabled && h.key.trim().toLowerCase() == 'authorization');
  if (hasAuthorizationHeader) return endpoint;

  return endpoint.copyWith(headers: [
    ...endpoint.headers,
    KeyValueEntry(key: 'Authorization', value: 'Bearer ${session.accessToken.trim()}'),
  ]);
}
