import 'package:api_flow_studio/engine/session/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Session', () {
    test('starts empty with attach and capture on', () {
      const session = Session();

      expect(session.accessToken, isEmpty);
      expect(session.refreshToken, isEmpty);
      expect(session.attachAuth, isTrue);
      expect(session.captureTokens, isTrue);
      expect(session.hasToken, isFalse);
    });

    test('hasToken follows the access token only', () {
      expect(const Session(accessToken: 'a').hasToken, isTrue);
      expect(const Session(refreshToken: 'r').hasToken, isFalse);
      expect(const Session(accessToken: '   ').hasToken, isFalse);
    });

    test('copyWith changes only the given fields', () {
      const session = Session(accessToken: 'a', refreshToken: 'r');

      final next = session.copyWith(accessToken: 'b', attachAuth: false);

      expect(next.accessToken, 'b');
      expect(next.refreshToken, 'r');
      expect(next.attachAuth, isFalse);
      expect(next.captureTokens, isTrue);
    });

    test('value equality', () {
      expect(const Session(accessToken: 'a'), const Session(accessToken: 'a'));
      expect(const Session(accessToken: 'a'), isNot(const Session(accessToken: 'b')));
    });

    test('toString never prints a token value', () {
      const session = Session(accessToken: 'super-secret-access', refreshToken: 'super-secret-refresh');

      expect(session.toString(), isNot(contains('super-secret')));
    });
  });

  group('sessionVariables', () {
    test('exposes the non-empty tokens under session_* names', () {
      const session = Session(accessToken: 'a1', refreshToken: 'r1');

      expect(sessionVariables(session), {'session_access_token': 'a1', 'session_refresh_token': 'r1'});
    });

    test('omits empty tokens', () {
      expect(sessionVariables(const Session(accessToken: 'a1')), {'session_access_token': 'a1'});
      expect(sessionVariables(const Session()), isEmpty);
    });
  });
}
