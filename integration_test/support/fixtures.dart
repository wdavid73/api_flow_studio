import 'dart:convert';

/// The moment every journey starts at: the session clock reads this unless a
/// journey moves it.
final DateTime seedNow = DateTime.utc(2026, 10, 2, 12);

/// A fake (unsigned) JWT whose payload is [claims].
String fakeJwt(Map<String, Object?> claims) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.signature';
}

/// What the demo `/login` hands out: an access token that expires 12 minutes
/// after [seedNow], and a refresh token.
final String fakeAccessToken = fakeJwt({
  'sub': 'user-42',
  'exp': seedNow.add(const Duration(minutes: 12)).millisecondsSinceEpoch ~/ 1000,
});

const String fakeRefreshToken = 'refresh-token-1';
