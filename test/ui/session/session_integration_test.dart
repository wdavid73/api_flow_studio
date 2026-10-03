import 'dart:async';
import 'dart:io';

import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/session/session.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/flows/flow_run_view_screen.dart';
import 'package:api_flow_studio/ui/request_builder/request_draft_provider.dart';
import 'package:api_flow_studio/ui/request_builder/send_provider.dart';
import 'package:api_flow_studio/ui/session/session_provider.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

const _login = Endpoint(id: 'draft', groupId: '', name: 'Login', method: 'POST', url: 'https://x.test/login');
const _profile = Endpoint(id: 'draft', groupId: '', name: 'Profile', method: 'GET', url: 'https://x.test/me');

const _loginBody = {'data': {'accessToken': 'tok-secret-A', 'refreshToken': 'ref-secret-A'}};

void main() {
  setUpAll(() => registerFallbackValue(FakeEndpoint()));

  late MockRequestExecutor raw;
  late JsonStore store;
  late ProviderContainer container;

  Future<void> setUpContainer({JsonStore? withStore, String? activeId = 'a'}) async {
    raw = MockRequestExecutor();
    store = withStore ?? JsonStore.inMemory();
    await store.writeEnvironments(const [
      Environment(id: 'a', name: 'Dev'),
      Environment(id: 'b', name: 'QA'),
    ]);
    await store.writeActiveEnvironmentId(activeId);
    container = ProviderContainer(overrides: [
      jsonStoreProvider.overrideWithValue(store),
      requestExecutorProvider.overrideWithValue(raw),
    ]);
    addTearDown(container.dispose);
    await container.read(environmentsProvider.future);
  }

  void answerWith(ExecutedResponse Function(Endpoint) respond) {
    when(() => raw.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((invocation) async => respond(invocation.positionalArguments.first as Endpoint));
  }

  Future<void> send(Endpoint endpoint) async {
    container.read(requestDraftProvider.notifier).loadEndpoint(endpoint);
    await container.read(sendStateProvider.notifier).send();
  }

  List<Endpoint> sentEndpoints() =>
      verify(() => raw.execute(captureAny(), variables: any(named: 'variables'))).captured.cast<Endpoint>();

  Session sessionOf(String envKey) => container.read(sessionsProvider)[envKey] ?? const Session();

  ExecutedResponse loginOrOk(Endpoint e) =>
      e.name == 'Login' ? const ExecutedResponse(status: 200, body: _loginBody) : const ExecutedResponse(status: 200, body: {});

  test('a login send stores the tokens for the active environment only', () async {
    await setUpContainer();
    answerWith(loginOrOk);

    await send(_login);

    expect(sessionOf('a').accessToken, 'tok-secret-A');
    expect(sessionOf('a').refreshToken, 'ref-secret-A');
    expect(sessionOf('b').hasToken, isFalse);
    expect(container.read(activeSessionProvider).accessToken, 'tok-secret-A');
  });

  test('the next send in that environment carries the Bearer token, another environment does not', () async {
    await setUpContainer();
    answerWith(loginOrOk);
    await send(_login);

    await send(_profile);
    await container.read(environmentsProvider.notifier).setActive('b');
    await send(_profile);

    final sent = sentEndpoints();
    expect(sent[0].headers, isEmpty); // the login itself
    expect(sent[1].headers.single, const KeyValueEntry(key: 'Authorization', value: 'Bearer tok-secret-A'));
    expect(sent[2].headers, isEmpty); // environment B has no session
  });

  test('without an active environment a separate "no environment" session is used', () async {
    await setUpContainer(activeId: null);
    answerWith(loginOrOk);

    await send(_login);

    expect(sessionOf('').accessToken, 'tok-secret-A');
    expect(sessionOf('a').hasToken, isFalse);
  });

  test('tokens go to the environment that was active when the request started', () async {
    await setUpContainer();
    final gate = Completer<ExecutedResponse>();
    when(() => raw.execute(any(), variables: any(named: 'variables'))).thenAnswer((_) => gate.future);

    container.read(requestDraftProvider.notifier).loadEndpoint(_login);
    final inFlight = container.read(sendStateProvider.notifier).send();
    await Future<void>.delayed(Duration.zero);
    await container.read(environmentsProvider.notifier).setActive('b');
    gate.complete(const ExecutedResponse(status: 200, body: _loginBody));
    await inFlight;

    expect(sessionOf('a').accessToken, 'tok-secret-A');
    expect(sessionOf('b').hasToken, isFalse);
  });

  test('session variables reach the raw executor', () async {
    await setUpContainer();
    container.read(sessionsProvider.notifier).update('a', const Session(accessToken: 'tok', refreshToken: 'ref'));
    answerWith(loginOrOk);

    await send(_profile);

    final variables = verify(() => raw.execute(any(), variables: captureAny(named: 'variables'))).captured.single
        as Map<String, String>;
    expect(variables, {'session_access_token': 'tok', 'session_refresh_token': 'ref'});
  });

  test('overriding only the raw executor keeps working with an empty session', () async {
    await setUpContainer();
    answerWith(loginOrOk);

    await send(_profile);

    final variables = verify(() => raw.execute(any(), variables: captureAny(named: 'variables'))).captured.single
        as Map<String, String>;
    expect(variables, <String, String>{});
  });

  test('nothing about the session is written to the data folder', () async {
    final dir = await Directory.systemTemp.createTemp('session_storage_test_');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    await setUpContainer(withStore: JsonStore(directory: dir));
    answerWith(loginOrOk);

    // An unsaved draft writes no history, so any trace of a token in the
    // folder would have to come from the session itself.
    await send(_login);
    await send(_profile);

    expect(sessionOf('a').hasToken, isTrue);
    for (final entity in dir.listSync(recursive: true).whereType<File>()) {
      final text = entity.readAsStringSync();
      expect(text, isNot(contains('tok-secret-A')), reason: entity.path);
      expect(text, isNot(contains('ref-secret-A')), reason: entity.path);
    }
  });

  testWidgets('a flow run sends through the session: Bearer attached and login tokens captured', (tester) async {
    await setUpContainer();
    container.read(sessionsProvider.notifier).update('a', const Session(accessToken: 'tok-flow'));
    answerWith((e) => e.name == 'Login'
        ? const ExecutedResponse(status: 200, body: _loginBody)
        : const ExecutedResponse(status: 200, body: {}));

    const loginStep = Endpoint(id: 'e-login', groupId: 'g', name: 'Login', method: 'POST', url: 'https://x.test/login');
    const meStep = Endpoint(id: 'e-me', groupId: 'g', name: 'Profile', method: 'GET', url: 'https://x.test/me');

    await tester.runAsync(() async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: FlowRunViewScreen(
              flow: Flow(
                id: 'f',
                name: 'Login then profile',
                steps: [FlowStep(endpointId: 'e-login'), FlowStep(endpointId: 'e-me')],
              ),
              endpoints: {'e-login': loginStep, 'e-me': meStep},
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
    });

    final sent = sentEndpoints();
    expect(sent[0].headers.single.value, 'Bearer tok-flow'); // login step already carries the old token
    expect(sent[1].headers.single.value, 'Bearer tok-secret-A'); // the login captured a fresh one
    expect(sessionOf('a').accessToken, 'tok-secret-A');
  });
}
