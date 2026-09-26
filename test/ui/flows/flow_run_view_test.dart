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
    url: '{{base_url}}/exists',
  );
  const sendOtp = Endpoint(
    id: 'e-2',
    groupId: 'g-1',
    name: 'Send OTP',
    method: 'POST',
    url: '{{base_url}}/otp',
  );
  const createUser = Endpoint(
    id: 'e-3',
    groupId: 'g-1',
    name: 'Create user',
    method: 'POST',
    url: '{{base_url}}/users',
  );
  final endpoints = {
    checkUser.id: checkUser,
    sendOtp.id: sendOtp,
    createUser.id: createUser,
  };

  Future<MockRequestExecutor> pumpRunView(
    WidgetTester tester,
    Flow flow, {
    required MockRequestExecutor executor,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('flow_run_view_test_');
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

  testWidgets('a fully-passing 3-step run shows success icons and a 3-passed summary',
      (tester) async {
    await tester.runAsync(() async {
      final executor = MockRequestExecutor();
      when(() => executor.execute(any(), variables: any(named: 'variables')))
          .thenAnswer((_) async => const ExecutedResponse(status: 200, body: {}));

      final flow = Flow(
        id: 'f-1',
        name: 'Registration Flow',
        steps: const [
          FlowStep(endpointId: 'e-1'),
          FlowStep(endpointId: 'e-2'),
          FlowStep(endpointId: 'e-3'),
        ],
      );

      await pumpRunView(tester, flow, executor: executor);

      expect(find.text('3 passed'), findsOneWidget);
      expect(find.text('0 failed'), findsOneWidget);
      expect(find.text('0 skipped'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        final icon = tester.widget<Icon>(find.byKey(ValueKey('run-step-status-icon-$i')));
        expect(icon.icon, Icons.check_circle);
      }

      final captured = verify(
        () => executor.execute(checkUser, variables: captureAny(named: 'variables')),
      ).captured.single as Map<String, String>;
      expect(captured['base_url'], 'https://api.dev');
    });
  });

  testWidgets('a failing step with stopOnFailure shows failure then skipped icons',
      (tester) async {
    await tester.runAsync(() async {
      final flow = Flow(
        id: 'f-1',
        name: 'Registration Flow',
        steps: const [
          FlowStep(
            endpointId: 'e-1',
            assertField: 'response.status',
            assertExpected: '200',
          ),
          FlowStep(endpointId: 'e-2'),
          FlowStep(endpointId: 'e-3'),
        ],
      );

      final executor = MockRequestExecutor();
      when(() => executor.execute(checkUser, variables: any(named: 'variables')))
          .thenAnswer((_) async => const ExecutedResponse(status: 404));

      await pumpRunView(tester, flow, executor: executor);

      expect(find.text('0 passed'), findsOneWidget);
      expect(find.text('1 failed'), findsOneWidget);
      expect(find.text('2 skipped'), findsOneWidget);

      final failIcon = tester.widget<Icon>(find.byKey(const ValueKey('run-step-status-icon-0')));
      expect(failIcon.icon, Icons.cancel);
      final skip1 = tester.widget<Icon>(find.byKey(const ValueKey('run-step-status-icon-1')));
      expect(skip1.icon, Icons.do_not_disturb_on);
      final skip2 = tester.widget<Icon>(find.byKey(const ValueKey('run-step-status-icon-2')));
      expect(skip2.icon, Icons.do_not_disturb_on);

      verifyNever(() => executor.execute(sendOtp, variables: any(named: 'variables')));
      verifyNever(() => executor.execute(createUser, variables: any(named: 'variables')));
    });
  });

  testWidgets('tapping re-run re-executes the flow', (tester) async {
    await tester.runAsync(() async {
      final flow = Flow(
        id: 'f-1',
        name: 'Registration Flow',
        steps: const [FlowStep(endpointId: 'e-1')],
      );
      final executor = MockRequestExecutor();
      when(() => executor.execute(any(), variables: any(named: 'variables')))
          .thenAnswer((_) async => const ExecutedResponse(status: 200));

      await pumpRunView(tester, flow, executor: executor);

      await tester.tap(find.byKey(const Key('re-run-flow-button')));
      await settle(tester);

      verify(() => executor.execute(checkUser, variables: any(named: 'variables'))).called(2);
    });
  });
}
