import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/session/session.dart';
import 'package:api_flow_studio/engine/session/session_apply.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Endpoint endpoint({List<KeyValueEntry> headers = const [], AuthConfig auth = const AuthConfig.none()}) => Endpoint(
        id: 'e1',
        groupId: 'g1',
        name: 'Test',
        method: 'GET',
        url: 'https://x.test',
        headers: headers,
        authConfig: auth,
      );

  const session = Session(accessToken: 'tok');

  test('adds a Bearer Authorization header when a token exists', () {
    final result = applySession(endpoint(), session);

    expect(result.headers, [const KeyValueEntry(key: 'Authorization', value: 'Bearer tok')]);
  });

  test('keeps the existing headers and appends the Authorization after them', () {
    final result = applySession(endpoint(headers: const [KeyValueEntry(key: 'X-A', value: '1')]), session);

    expect(result.headers.map((h) => h.key), ['X-A', 'Authorization']);
  });

  test('does nothing when attachAuth is off', () {
    final original = endpoint();

    expect(identical(applySession(original, session.copyWith(attachAuth: false)), original), isTrue);
  });

  test('does nothing without an access token', () {
    final original = endpoint();

    expect(identical(applySession(original, const Session()), original), isTrue);
    expect(identical(applySession(original, const Session(refreshToken: 'r')), original), isTrue);
  });

  test('never overrides an Authorization header, whatever its capitalization', () {
    for (final key in ['Authorization', 'authorization', 'AUTHORIZATION']) {
      final original = endpoint(headers: [KeyValueEntry(key: key, value: 'Basic abc')]);

      expect(identical(applySession(original, session), original), isTrue, reason: key);
    }
  });

  test('a disabled Authorization header does not block the session token', () {
    final result = applySession(
      endpoint(headers: const [KeyValueEntry(key: 'Authorization', value: 'old', enabled: false)]),
      session,
    );

    expect(result.headers.last, const KeyValueEntry(key: 'Authorization', value: 'Bearer tok'));
  });

  test('never overrides an explicit AuthConfig', () {
    final bearer = endpoint(auth: const AuthConfig.bearer(token: 'mine'));
    final basic = endpoint(auth: const AuthConfig.basic(username: 'u', password: 'p'));

    expect(identical(applySession(bearer, session), bearer), isTrue);
    expect(identical(applySession(basic, session), basic), isTrue);
  });

  test('trims the token before using it', () {
    final result = applySession(endpoint(), const Session(accessToken: '  tok  '));

    expect(result.headers.single.value, 'Bearer tok');
  });
}
