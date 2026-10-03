import 'dart:convert';

import 'package:api_flow_studio/engine/session/jwt_claims.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fake (unsigned) JWT whose payload is [claims], base64url without padding.
String jwt(Map<String, Object?> claims) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.signature';
}

void main() {
  final now = DateTime.utc(2026, 10, 2, 12);
  int secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

  group('JwtClaims.tryParse', () {
    test('reads sub and exp from a valid token', () {
      final claims = JwtClaims.tryParse(jwt({'sub': 'user-42', 'exp': secs(now)}))!;

      expect(claims.subject, 'user-42');
      expect(claims.expiresAt, now);
    });

    test('decodes a payload whose base64url padding was stripped', () {
      // These payload lengths produce 0, 1 and 2 padding characters.
      for (final sub in ['a', 'ab', 'abc']) {
        expect(JwtClaims.tryParse(jwt({'sub': sub}))?.subject, sub, reason: sub);
      }
    });

    test('decodes url-safe characters (- and _)', () {
      final claims = JwtClaims.tryParse(jwt({'sub': 'úû??>>~~'}))!;

      expect(claims.subject, 'úû??>>~~');
    });

    test('exp and sub are optional', () {
      final claims = JwtClaims.tryParse(jwt({'iss': 'someone'}))!;

      expect(claims.subject, isNull);
      expect(claims.expiresAt, isNull);
    });

    test('a non-numeric exp counts as missing', () {
      expect(JwtClaims.tryParse(jwt({'exp': 'soon'}))!.expiresAt, isNull);
    });

    test('a fractional exp is accepted', () {
      final claims = JwtClaims.tryParse(jwt({'exp': secs(now) + 0.5}))!;

      expect(claims.expiresAt, isNotNull);
    });

    test('returns null for things that are not a JWT, instead of throwing', () {
      expect(JwtClaims.tryParse(''), isNull);
      expect(JwtClaims.tryParse('abc'), isNull);
      expect(JwtClaims.tryParse('a.b'), isNull);
      expect(JwtClaims.tryParse('a.%%%.c'), isNull);
      expect(JwtClaims.tryParse('a.${base64Url.encode(utf8.encode('not json'))}.c'), isNull);
      expect(JwtClaims.tryParse('a.${base64Url.encode(utf8.encode('[1,2]'))}.c'), isNull);
    });

    test('ignores surrounding whitespace', () {
      expect(JwtClaims.tryParse('  ${jwt({'sub': 'x'})}\n')?.subject, 'x');
    });
  });

  group('expiresIn', () {
    test('is negative for a past exp', () {
      final claims = JwtClaims.tryParse(jwt({'exp': secs(now.subtract(const Duration(minutes: 5)))}))!;

      expect(claims.expiresIn(now), const Duration(minutes: -5));
    });

    test('is positive for a future exp', () {
      final claims = JwtClaims.tryParse(jwt({'exp': secs(now.add(const Duration(hours: 2)))}))!;

      expect(claims.expiresIn(now), const Duration(hours: 2));
    });

    test('is null without an exp', () {
      expect(JwtClaims.tryParse(jwt({'sub': 'x'}))!.expiresIn(now), isNull);
    });

    test('works whether now is utc or local', () {
      final claims = JwtClaims.tryParse(jwt({'exp': secs(now.add(const Duration(minutes: 10)))}))!;

      expect(claims.expiresIn(now.toLocal()), const Duration(minutes: 10));
    });
  });
}
