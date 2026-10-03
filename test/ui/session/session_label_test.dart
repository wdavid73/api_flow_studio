import 'dart:convert';

import 'package:api_flow_studio/engine/session/session.dart';
import 'package:api_flow_studio/ui/session/session_label.dart';
import 'package:flutter_test/flutter_test.dart';

String jwt(Map<String, Object?> claims) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.sig';
}

void main() {
  final now = DateTime.utc(2026, 10, 2, 12);
  int secs(Duration fromNow) => now.add(fromNow).millisecondsSinceEpoch ~/ 1000;

  SessionLabel labelFor(Session session) => sessionLabel(session, now);

  test('no token says so and that nothing is stored on disk', () {
    final label = labelFor(const Session());

    expect(label.top, 'No token');
    expect(label.bottom, 'kept in memory only');
    expect(label.tone, SessionTone.none);
  });

  test('a blank access token counts as no token', () {
    expect(labelFor(const Session(accessToken: '   ')).tone, SessionTone.none);
  });

  test('a JWT expiring within 90 minutes shows minutes', () {
    final label = labelFor(Session(accessToken: jwt({'exp': secs(const Duration(minutes: 12))})));

    expect(label.top, 'Expires in 12 min');
    expect(label.bottom, 'Authorization: Bearer');
    expect(label.tone, SessionTone.valid);
  });

  test('a JWT expiring in 89 minutes still shows minutes, 90 shows hours', () {
    expect(labelFor(Session(accessToken: jwt({'exp': secs(const Duration(minutes: 89))}))).top, 'Expires in 89 min');
    expect(labelFor(Session(accessToken: jwt({'exp': secs(const Duration(minutes: 90))}))).top, 'Expires in 2 h');
  });

  test('a JWT expiring in hours shows rounded hours', () {
    expect(labelFor(Session(accessToken: jwt({'exp': secs(const Duration(hours: 5))}))).top, 'Expires in 5 h');
    expect(labelFor(Session(accessToken: jwt({'exp': secs(const Duration(hours: 26))}))).top, 'Expires in 26 h');
  });

  test('under 30 seconds left still reads as at least 1 minute', () {
    expect(labelFor(Session(accessToken: jwt({'exp': secs(const Duration(seconds: 10))}))).top, 'Expires in 1 min');
  });

  test('an expired JWT says Token expired with the expired tone', () {
    final label = labelFor(Session(accessToken: jwt({'exp': secs(const Duration(minutes: -1))})));

    expect(label.top, 'Token expired');
    expect(label.bottom, 'Authorization: Bearer');
    expect(label.tone, SessionTone.expired);
  });

  test('a token that expires exactly now is expired', () {
    expect(labelFor(Session(accessToken: jwt({'exp': secs(Duration.zero)}))).tone, SessionTone.expired);
  });

  test('a JWT without exp, and a token that is not a JWT, read as Token saved', () {
    for (final token in [jwt({'sub': 'x'}), 'opaque-token']) {
      final label = labelFor(Session(accessToken: token));

      expect(label.top, 'Token saved', reason: token);
      expect(label.tone, SessionTone.valid);
    }
  });

  test('the label never contains the token', () {
    const token = 'super-secret-token-value';
    final label = labelFor(const Session(accessToken: token));

    expect('${label.top} ${label.bottom}', isNot(contains(token)));
  });
}
