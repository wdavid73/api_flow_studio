import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/ui/request_builder/request_bar.dart';
import 'package:api_flow_studio/ui/request_builder/send_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeEndpoint());
  });

  late MockRequestExecutor executor;

  Future<void> pumpRequestBar(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [requestExecutorProvider.overrideWithValue(executor)],
        child: const MaterialApp(home: Scaffold(body: RequestBar())),
      ),
    );
  }

  setUp(() {
    executor = MockRequestExecutor();
  });

  testWidgets('typing a URL and tapping Send shows the response status/time/size/body',
      (tester) async {
    when(() => executor.execute(any(), variables: any(named: 'variables'))).thenAnswer(
      (_) async => const ExecutedResponse(
        status: 200,
        body: '{"ok":true}',
        elapsedMs: 42,
        sizeBytes: 11,
      ),
    );

    await pumpRequestBar(tester);
    await tester.enterText(find.byKey(const Key('request-url-field')), 'https://httpbin.org/get');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.textContaining('200'), findsOneWidget);
    expect(find.textContaining('42'), findsOneWidget);
    expect(find.textContaining('"ok"'), findsOneWidget);
    expect(find.textContaining('true'), findsOneWidget);
  });

  testWidgets('sends the exact URL that was typed, with an empty variable map', (tester) async {
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 200));

    await pumpRequestBar(tester);
    await tester.enterText(find.byKey(const Key('request-url-field')), 'https://httpbin.org/get');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    final captured = verify(
      () => executor.execute(captureAny(), variables: captureAny(named: 'variables')),
    ).captured;
    expect((captured[0] as Endpoint).url, 'https://httpbin.org/get');
    expect(captured[1], <String, String>{});
  });

  testWidgets('a transport error shows an inline error message, not a crash', (tester) async {
    when(() => executor.execute(any(), variables: any(named: 'variables'))).thenAnswer(
      (_) async => const ExecutedResponse(error: 'Connection refused'),
    );

    await pumpRequestBar(tester);
    await tester.enterText(find.byKey(const Key('request-url-field')), 'https://bad.invalid');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Connection refused'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a header added on the Headers tab is part of what gets sent', (tester) async {
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 200));

    await pumpRequestBar(tester);
    await tester.tap(find.text('Headers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add row'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('kv-key-field')), 'X-Test');
    await tester.enterText(find.byKey(const Key('kv-value-field')), '123');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    final endpoint = verify(
      () => executor.execute(captureAny(), variables: any(named: 'variables')),
    ).captured.single as Endpoint;
    expect(endpoint.headers, [const KeyValueEntry(key: 'X-Test', value: '123')]);
  });

  testWidgets('switching Body to JSON and typing sends that raw body', (tester) async {
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 201));

    await pumpRequestBar(tester);
    await tester.tap(find.text('Body'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JSON'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('json-body-field')), '{"a":1}');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    final endpoint = verify(
      () => executor.execute(captureAny(), variables: any(named: 'variables')),
    ).captured.single as Endpoint;
    expect(endpoint.body, const RequestBody.json('{"a":1}'));
  });

  testWidgets('typing a description on the Docs tab sends it along with the request',
      (tester) async {
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 200));

    await pumpRequestBar(tester);
    await tester.tap(find.text('Docs'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('docs-description-field')),
      'Creates a new user account.',
    );
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    final endpoint = verify(
      () => executor.execute(captureAny(), variables: any(named: 'variables')),
    ).captured.single as Endpoint;
    expect(endpoint.description, 'Creates a new user account.');
  });

  testWidgets('switching Auth to Bearer and typing a token sends that AuthConfig', (tester) async {
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 200));

    await pumpRequestBar(tester);
    await tester.tap(find.text('Auth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('auth-token-field')), 'abc123');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    final endpoint = verify(
      () => executor.execute(captureAny(), variables: any(named: 'variables')),
    ).captured.single as Endpoint;
    expect(endpoint.authConfig, const AuthConfig.bearer(token: 'abc123'));
  });
}
