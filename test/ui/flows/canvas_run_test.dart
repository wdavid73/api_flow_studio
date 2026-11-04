import 'dart:async';

import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/ui/flows/flow_run_provider.dart';
import 'package:api_flow_studio/ui/flows/flows_screen.dart';
import 'package:api_flow_studio/ui/theme/widgets/status_badge.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'canvas_run_harness.dart';

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

void main() {
  setUpAll(() => registerFallbackValue(FakeEndpoint()));

  const checkUser = Endpoint(id: 'e-1', groupId: 'g-1', name: 'Check user', method: 'GET', url: '{{base_url}}/exists');
  const sendOtp = Endpoint(id: 'e-2', groupId: 'g-1', name: 'Send OTP', method: 'POST', url: '{{base_url}}/otp');
  const createUser = Endpoint(
    id: 'e-3',
    groupId: 'g-1',
    name: 'Create user',
    method: 'POST',
    url: '{{base_url}}/users?token={{otp_token}}',
  );
  final endpoints = {checkUser.id: checkUser, sendOtp.id: sendOtp, createUser.id: createUser};
  const flow = Flow(
    id: 'f-1',
    name: 'Sign up',
    steps: [
      FlowStep(endpointId: 'e-1'),
      FlowStep(endpointId: 'e-2', extract: {'otp_token': 'response.body.token'}),
      FlowStep(endpointId: 'e-3'),
    ],
  );

  late MockRequestExecutor executor;

  setUp(() {
    executor = MockRequestExecutor();
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 200, body: {'token': 'tok-1'}, elapsedMs: 10));
  });

  Finder status(int i) => find.byKey(ValueKey('step-node-status-$i'));

  testWidgets('Run paints each node status and the summary strip', (tester) async {
    await pumpCanvasRun(tester, flow: flow, endpoints: endpoints, executor: executor);

    expect(find.text('3 passed'), findsOneWidget);
    expect(find.text('0 failed'), findsOneWidget);
    expect(find.text('0 skipped'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('run-summary-total'))).data, '30 ms');
    for (final i in [0, 1, 2]) {
      expect(find.descendant(of: status(i), matching: find.byType(StatusBadge)), findsOneWidget, reason: 'step $i');
    }
  });

  testWidgets('a failing step with stop on failure skips the rest and opens its error in the panel', (tester) async {
    when(() => executor.execute(sendOtp, variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(error: 'boom'));

    final app = await pumpCanvasRun(tester, flow: flow, endpoints: endpoints, executor: executor);

    expect(find.text('1 passed'), findsOneWidget);
    expect(find.text('1 failed'), findsOneWidget);
    expect(find.text('1 skipped'), findsOneWidget);
    verifyNever(() => executor.execute(createUser, variables: any(named: 'variables')));
    expect(app.container.read(selectedStepIndexProvider), 1);
    expect(find.text('Error Details'), findsOneWidget);
  });

  testWidgets('stop on failure off keeps running after a failure', (tester) async {
    when(() => executor.execute(sendOtp, variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(error: 'boom'));
    final lenient = flow.copyWith(steps: [
      flow.steps[0],
      flow.steps[1].copyWith(stopOnFailure: false),
      flow.steps[2],
    ]);

    await pumpCanvasRun(tester, flow: lenient, endpoints: endpoints, executor: executor);

    expect(find.text('2 passed'), findsOneWidget);
    verify(() => executor.execute(createUser, variables: any(named: 'variables'))).called(1);
  });

  testWidgets('node fields update from the run response', (tester) async {
    when(() => executor.execute(checkUser, variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 200, body: {'fresh': 1}));

    await pumpCanvasRun(tester, flow: flow, endpoints: endpoints, executor: executor);

    expect(find.descendant(of: find.byKey(const ValueKey('step-node-0')), matching: find.text('fresh')), findsOneWidget);
  });

  testWidgets('Run up to here sends only the pending steps up to that node', (tester) async {
    await pumpCanvasRun(tester, flow: flow, endpoints: endpoints, executor: executor, run: false);

    await tester.tap(find.byKey(const ValueKey('run-until-1')));
    await tester.pumpAndSettle();

    verify(() => executor.execute(checkUser, variables: any(named: 'variables'))).called(1);
    verify(() => executor.execute(sendOtp, variables: any(named: 'variables'))).called(1);
    verifyNever(() => executor.execute(createUser, variables: any(named: 'variables')));

    clearInteractions(executor);
    await tester.tap(find.byKey(const ValueKey('step-node-menu-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('step-node-run-until-2')));
    await tester.pumpAndSettle();

    verifyNever(() => executor.execute(checkUser, variables: any(named: 'variables')));
    final variables = verify(() => executor.execute(createUser, variables: captureAny(named: 'variables')))
        .captured
        .single as Map<String, String>;
    expect(variables['otp_token'], 'tok-1');
  });

  testWidgets('Run again from here re-sends from that step to the end', (tester) async {
    await pumpCanvasRun(tester, flow: flow, endpoints: endpoints, executor: executor);
    clearInteractions(executor);

    await tester.tap(find.byKey(const ValueKey('step-node-menu-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('step-node-rerun-from-1')));
    await tester.pumpAndSettle();

    verifyNever(() => executor.execute(checkUser, variables: any(named: 'variables')));
    verify(() => executor.execute(sendOtp, variables: any(named: 'variables'))).called(1);
    verify(() => executor.execute(createUser, variables: any(named: 'variables'))).called(1);
  });

  testWidgets('Run again from here is only offered once there are results', (tester) async {
    await pumpCanvasRun(tester, flow: flow, endpoints: endpoints, executor: executor, run: false);

    await tester.tap(find.byKey(const ValueKey('step-node-menu-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('step-node-rerun-from-1')), findsNothing);
    expect(find.byKey(const ValueKey('step-node-run-until-1')), findsOneWidget);
  });

  testWidgets('the Run tab shows the request sent with the resolved url', (tester) async {
    await pumpCanvasRun(tester, flow: flow, endpoints: endpoints, executor: executor);

    await openRunTab(tester, 2);
    await tester.tap(find.text('Request Sent'));
    await tester.pumpAndSettle();

    expect(find.text('POST https://api.dev/users?token=tok-1'), findsOneWidget);
  });

  testWidgets('editing is locked while running', (tester) async {
    final gate = Completer<ExecutedResponse>();
    when(() => executor.execute(checkUser, variables: any(named: 'variables'))).thenAnswer((_) => gate.future);

    await pumpCanvasRun(tester, flow: flow, endpoints: endpoints, executor: executor, settle: (t) => t.pump());
    await tester.pump();

    expect(tester.widget<FilledButton>(find.byKey(const Key('run-flow-button'))).onPressed, isNull);
    expect(find.byKey(const Key('run-in-progress-indicator')), findsOneWidget);
    expect(tester.widget<PopupMenuButton<Object?>>(find.byKey(const ValueKey('step-node-menu-0'))).enabled, isFalse);

    gate.complete(const ExecutedResponse(status: 200));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('run-flow-button'))).onPressed, isNotNull);
  });

  testWidgets('running never adds history entries', (tester) async {
    final app = await pumpCanvasRun(tester, flow: flow, endpoints: endpoints, executor: executor);

    for (final id in endpoints.keys) {
      expect(await app.store.readHistory(id), isEmpty, reason: id);
    }
    expect(app.container.read(flowRunProvider('f-1')).results.whereType<Object>(), hasLength(3));
  });

  testWidgets('running again re-executes the whole flow', (tester) async {
    await pumpCanvasRun(tester, flow: flow, endpoints: endpoints, executor: executor);
    clearInteractions(executor);

    await tester.tap(find.byKey(const Key('run-flow-button')));
    await tester.pumpAndSettle();

    verify(() => executor.execute(checkUser, variables: any(named: 'variables'))).called(1);
    verify(() => executor.execute(createUser, variables: any(named: 'variables'))).called(1);
  });
}
