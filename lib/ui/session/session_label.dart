import '../../engine/session/jwt_claims.dart';
import '../../engine/session/session.dart';

/// How the session button is colored.
enum SessionTone { none, valid, expired }

/// The two lines of the header session button and its tone.
class SessionLabel {
  const SessionLabel({required this.top, required this.bottom, required this.tone});

  final String top;
  final String bottom;
  final SessionTone tone;
}

/// Describes [session] as of [now]: the time left on a JWT (`Expires in 12
/// min`, or hours from 90 minutes up), `Token expired`, `Token saved` for a
/// token without a readable expiry, or `No token`. Never includes the token.
SessionLabel sessionLabel(Session session, DateTime now) {
  if (!session.hasToken) {
    return const SessionLabel(top: 'No token', bottom: 'kept in memory only', tone: SessionTone.none);
  }

  const bottom = 'Authorization: Bearer';
  final remaining = JwtClaims.tryParse(session.accessToken)?.expiresIn(now);

  if (remaining == null) {
    return const SessionLabel(top: 'Token saved', bottom: bottom, tone: SessionTone.valid);
  }
  if (remaining <= Duration.zero) {
    return const SessionLabel(top: 'Token expired', bottom: bottom, tone: SessionTone.expired);
  }

  final minutes = (remaining.inMilliseconds / Duration.millisecondsPerMinute).round().clamp(1, 1 << 30);
  final top = minutes < 90 ? 'Expires in $minutes min' : 'Expires in ${(minutes / 60).round()} h';
  return SessionLabel(top: top, bottom: bottom, tone: SessionTone.valid);
}
