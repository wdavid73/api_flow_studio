import 'dart:io';

import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/flows/flow_run_view_screen.dart';
import 'package:api_flow_studio/ui/request_builder/send_provider.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Real dart:io I/O (JsonStore) needs tester.runAsync(); see tasks/plan.md.

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

void main() {
  setUpAll(() => registerFallbackValue(FakeEndpoint()));

  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
  }

  const checkUser = Endpoint(
    id: 'e-1',
    groupId: 'g-1',
    name: 'Check user',
    method: 'GET',
    url: '{{base_url}}/users/exists',
  );
  const createUser = Endpoint(
    id: 'e-2',
    groupId: 'g-1',
    name: 'Create user',
    method: 'POST',
    url: '{{base_url}}/users?token={{otp_token}}',
  );
  final endpoints = {checkUser.id: checkUser, createUser.id: createUser};

  Future<MockRequestExecutor> pumpRunView(
    WidgetTester tester,
    Flow flow, {
    required MockRequestExecutor executor,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('flow_run_view_detail_test_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final store = JsonStore(directory: tempDir);
    await store.writeEnvironments(const [
      Environment(id: 'env-1', name: 'Dev', variables: {
        'base_url': EnvironmentVariable(value: 'https://api.dev'),
      }),
    ]);
    await store.writeActiveEnvironmentId('env-1');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsonStoreProvider.overrideWithValue(store),
          requestExecutorProvider.overrideWithValue(executor),
        ],
        child: MaterialApp(home: FlowRunViewScreen(flow: flow, endpoints: endpoints)),
      ),
    );
    await settle(tester);
    return executor;
  }

  testWidgets('expanding a successful step shows its interpolated request and response body',
      (tester) async {
    await tester.runAsync(() async {
      final flow = Flow(
        id: 'f-1',
        name: 'Flow',
        steps: const [FlowStep(endpointId: 'e-1')],
      );
      final executor = MockRequestExecutor();
      when(() => executor.execute(checkUser, variables: any(named: 'variables'))).thenAnswer(
        (_) async => const ExecutedResponse(status: 200, body: {'exists': true}),
      );

      await pumpRunView(tester, flow, executor: executor);

      // The only step auto-selects once the run completes (matching the
      // design's "active selection" on the most relevant step); tapping
      // its header again is a harmless re-selection.
      expect(find.byKey(const Key('rerun-from-step-0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('run-step-header-0')));
      await settle(tester);

      // Request Sent and Response Body are separate tabs now (the inspector
      // panel's tabbed layout) -- each tab's content only exists in the
      // tree once it's the active one, so switch to it before asserting.
      expect(find.textContaining('https://api.dev/users/exists'), findsOneWidget);

      await tester.tap(find.text('Response Body'));
      await tester.pumpAndSettle();
      expect(find.textContaining('"exists": true'), findsOneWidget);

      expect(find.byKey(const Key('rerun-from-step-0')), findsOneWidget);
    });
  });

  testWidgets('expanding a failed step shows the error detail panel with a classification',
      (tester) async {
    await tester.runAsync(() async {
      final flow = Flow(
        id: 'f-1',
        name: 'Flow',
        steps: const [
          FlowStep(endpointId: 'e-1', assertField: 'response.status', assertExpected: '200'),
        ],
      );
      final executor = MockRequestExecutor();
      when(() => executor.execute(checkUser, variables: any(named: 'variables')))
          .thenAnswer((_) async => const ExecutedResponse(status: 404));

      await pumpRunView(tester, flow, executor: executor);

      await tester.tap(find.byKey(const Key('run-step-header-0')));
      await settle(tester);

      expect(find.text('Assertion Failure'), findsOneWidget);
      expect(find.textContaining('Assertion failed'), findsWidgets);
    });
  });

  testWidgets('a skipped step cannot be expanded', (tester) async {
    await tester.runAsync(() async {
      final flow = Flow(
        id: 'f-1',
        name: 'Flow',
        steps: const [
          FlowStep(endpointId: 'e-1', assertField: 'response.status', assertExpected: '200'),
          FlowStep(endpointId: 'e-2'),
        ],
      );
      final executor = MockRequestExecutor();
      when(() => executor.execute(checkUser, variables: any(named: 'variables')))
          .thenAnswer((_) async => const ExecutedResponse(status: 404));

      await pumpRunView(tester, flow, executor: executor);

      await tester.tap(find.byKey(const Key('run-step-header-1')));
      await settle(tester);

      expect(find.byKey(const Key('rerun-from-step-1')), findsNothing);
    });
  });

  testWidgets(
      're-running from step 2 reuses step 1\'s extracted variable and does not re-call step 1',
      (tester) async {
    await tester.runAsync(() async {
      final flow = Flow(
        id: 'f-1',
        name: 'Flow',
        steps: [
          FlowStep(endpointId: 'e-1', extract: const {'otp_token': 'response.body.token'}),
          const FlowStep(endpointId: 'e-2'),
        ],
      );
      final executor = MockRequestExecutor();
      when(() => executor.execute(checkUser, variables: any(named: 'variables'))).thenAnswer(
        (_) async => const ExecutedResponse(status: 200, body: {'token': 'tok-abc'}),
      );
      when(() => executor.execute(createUser, variables: captureAny(named: 'variables')))
          .thenAnswer((_) async => const ExecutedResponse(status: 201));

      await pumpRunView(tester, flow, executor: executor);
      clearInteractions(executor);
      when(() => executor.execute(createUser, variables: captureAny(named: 'variables')))
          .thenAnswer((_) async => const ExecutedResponse(status: 201));

      await tester.tap(find.byKey(const Key('run-step-header-1')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('rerun-from-step-1')));
      await settle(tester);

      verifyNever(() => executor.execute(checkUser, variables: any(named: 'variables')));
      final captured = verify(
        () => executor.execute(createUser, variables: captureAny(named: 'variables')),
      ).captured.single as Map<String, String>;
      expect(captured['otp_token'], 'tok-abc');
    });
  });
}
