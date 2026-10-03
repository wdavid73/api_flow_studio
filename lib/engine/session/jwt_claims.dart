import 'dart:convert';

/// The few claims of a JWT the UI shows: who it is for and when it expires.
/// Read from the (unverified) payload purely for display; the signature is
/// never checked and nothing here decides whether a token is valid.
class JwtClaims {
  const JwtClaims._({this.subject, this.expiresAt});

  /// The `sub` claim, if it is a string.
  final String? subject;

  /// The `exp` claim as a UTC instant, if it is a number.
  final DateTime? expiresAt;

  /// Parses [token], or returns null if it does not look like a JWT (not three
  /// dot-separated parts, payload not base64url, or not a JSON object).
  static JwtClaims? tryParse(String token) {
    final parts = token.trim().split('.');
    if (parts.length != 3) return null;

    final Object? payload;
    try {
      payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    } catch (_) {
      return null;
    }
    if (payload is! Map<String, dynamic>) return null;

    final sub = payload['sub'];
    final exp = payload['exp'];
    return JwtClaims._(
      subject: sub is String ? sub : null,
      expiresAt: exp is num
          ? DateTime.fromMillisecondsSinceEpoch((exp * 1000).round(), isUtc: true)
          : null,
    );
  }

  /// Time left until expiry as of [now]: negative once expired, null when the
  /// token has no `exp`.
  Duration? expiresIn(DateTime now) => expiresAt?.difference(now);
}
