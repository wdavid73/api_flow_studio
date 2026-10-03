import 'dart:convert';

import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/session/session.dart';
import 'package:api_flow_studio/engine/session/session_request_executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

const _endpoint = Endpoint(id: 'e1', groupId: 'g1', name: 'Login', method: 'POST', url: 'https://x.test/login');

void main() {
  setUpAll(() => registerFallbackValue(FakeEndpoint()));

  late MockRequestExecutor inner;
  late Session session;
  late int captures;
  late SessionRequestExecutor executor;

  void respondWith(ExecutedResponse response) {
    when(() => inner.execute(any(), variables: any(named: 'variables'))).thenAnswer((_) async => response);
  }

  setUp(() {
    inner = MockRequestExecutor();
    session = const Session();
    captures = 0;
    executor = SessionRequestExecutor(
      inner: inner,
      readSession: () => session,
      writeSession: (next) => session = next,
      onTokensCaptured: () => captures++,
    );
    respondWith(const ExecutedResponse(status: 200, body: {}));
  });

  ({Endpoint endpoint, Map<String, String> variables}) sentToInner() {
    final captured = verify(() => inner.execute(captureAny(), variables: captureAny(named: 'variables'))).captured;
    return (endpoint: captured[0] as Endpoint, variables: captured[1] as Map<String, String>);
  }

  group('before sending', () {
    test('with an empty session the inner executor gets the endpoint and variables untouched', () async {
      await executor.execute(_endpoint, variables: const {'base': 'x'});

      final sent = sentToInner();
      expect(identical(sent.endpoint, _endpoint), isTrue);
      expect(sent.variables, {'base': 'x'});
    });

    test('attaches the Bearer header', () async {
      session = const Session(accessToken: 'tok');

      await executor.execute(_endpoint, variables: const {});

      expect(sentToInner().endpoint.headers.single, const KeyValueEntry(key: 'Authorization', value: 'Bearer tok'));
    });

    test('adds the session variables and lets environment variables win', () async {
      session = const Session(accessToken: 'tok', refreshToken: 'ref');

      await executor.execute(_endpoint, variables: const {'session_refresh_token': 'from-env', 'base': 'b'});

      expect(sentToInner().variables, {
        'session_access_token': 'tok',
        'session_refresh_token': 'from-env',
        'base': 'b',
      });
    });

    test('does not attach when attachAuth is off', () async {
      session = const Session(accessToken: 'tok', attachAuth: false);

      await executor.execute(_endpoint, variables: const {});

      expect(sentToInner().endpoint.headers, isEmpty);
    });
  });

  group('capturing tokens', () {
    test('a 2xx JSON response stores the tokens it contains', () async {
      respondWith(const ExecutedResponse(status: 200, body: {'data': {'accessToken': 'a1', 'refreshToken': 'r1'}}));

      await executor.execute(_endpoint, variables: const {});

      expect(session.accessToken, 'a1');
      expect(session.refreshToken, 'r1');
      expect(captures, 1);
    });

    test('a JSON body that arrives as a string is parsed too', () async {
      respondWith(ExecutedResponse(status: 201, body: jsonEncode({'access_token': 'a2'})));

      await executor.execute(_endpoint, variables: const {});

      expect(session.accessToken, 'a2');
    });

    test('only the token found changes; the other one is kept', () async {
      session = const Session(accessToken: 'old-a', refreshToken: 'old-r');
      respondWith(const ExecutedResponse(status: 200, body: {'accessToken': 'new-a'}));

      await executor.execute(_endpoint, variables: const {});

      expect(session.accessToken, 'new-a');
      expect(session.refreshToken, 'old-r');
    });

    test('the switches are kept when tokens are captured', () async {
      session = const Session(attachAuth: false);
      respondWith(const ExecutedResponse(status: 200, body: {'accessToken': 'a'}));

      await executor.execute(_endpoint, variables: const {});

      expect(session.attachAuth, isFalse);
    });

    test('nothing is captured from a 4xx or 5xx response', () async {
      for (final status in [400, 401, 500]) {
        respondWith(ExecutedResponse(status: status, body: const {'accessToken': 'a'}));

        await executor.execute(_endpoint, variables: const {});
      }

      expect(session.hasToken, isFalse);
      expect(captures, 0);
    });

    test('nothing is captured from a transport error', () async {
      respondWith(const ExecutedResponse(error: 'boom'));

      await executor.execute(_endpoint, variables: const {});

      expect(session.hasToken, isFalse);
    });

    test('nothing is captured when captureTokens is off', () async {
      session = const Session(captureTokens: false);
      respondWith(const ExecutedResponse(status: 200, body: {'accessToken': 'a'}));

      await executor.execute(_endpoint, variables: const {});

      expect(session.hasToken, isFalse);
      expect(captures, 0);
    });

    test('a body that is not JSON captures nothing and does not throw', () async {
      for (final body in <Object?>['plain text', '<html></html>', null, 42]) {
        respondWith(ExecutedResponse(status: 200, body: body));

        await executor.execute(_endpoint, variables: const {});
      }

      expect(session.hasToken, isFalse);
    });

    test('the same tokens again are not reported as a capture', () async {
      session = const Session(accessToken: 'a', refreshToken: 'r');
      respondWith(const ExecutedResponse(status: 200, body: {'accessToken': 'a', 'refreshToken': 'r'}));

      await executor.execute(_endpoint, variables: const {});

      expect(captures, 0);
    });

    test('the response is returned unchanged', () async {
      const response = ExecutedResponse(status: 200, body: {'accessToken': 'a'}, elapsedMs: 7);
      respondWith(response);

      expect(await executor.execute(_endpoint, variables: const {}), response);
    });
  });
}
