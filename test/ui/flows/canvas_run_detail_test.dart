import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'canvas_run_harness.dart';

// Ported from flow_run_view_detail_test.dart: the run happens on the canvas and a
// step's result is read in the side panel's Run tab.

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
    await pumpCanvasRun(tester, flow: flow, endpoints: endpoints, executor: executor, settle: settle);
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

      await openRunTab(tester, 0, settle: settle);

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

  testWidgets('Request Sent shows the url actually sent, not a re-interpolated one', (tester) async {
    await tester.runAsync(() async {
      const withToken = Endpoint(
        id: 'e-3',
        groupId: 'g-1',
        name: 'Create',
        method: 'POST',
        url: '{{base_url}}/users/{{\$uuid}}',
      );
      final flow = Flow(id: 'f-1', name: 'Flow', steps: const [FlowStep(endpointId: 'e-3')]);
      final executor = MockRequestExecutor();
      when(() => executor.execute(withToken, variables: any(named: 'variables'))).thenAnswer(
        (_) async => const ExecutedResponse(
          status: 200,
          requestUrl: 'https://api.dev/users/3f2b8c1e-0000-4000-8000-000000000000',
        ),
      );

      await pumpCanvasRun(tester, flow: flow, endpoints: {withToken.id: withToken}, executor: executor, settle: settle);

      expect(
        find.textContaining('POST https://api.dev/users/3f2b8c1e-0000-4000-8000-000000000000'),
        findsOneWidget,
      );
      // The node and the panel show the request as written; what was sent has no tokens left.
      expect(find.descendant(of: find.byKey(const Key('run-inspector-surface')), matching: find.textContaining('{{')), findsNothing);
    });
  });

  testWidgets('expanding a failed step shows the error detail panel with a classification',
      (tester) async {
    await tester.runAsync(() async {
      final flow = Flow(
        id: 'f-1',
        name: 'Flow',
        steps: const [
          FlowStep(endpointId: 'e-1', assertions: [Assertion(field: 'response.status', expected: '200')]),
        ],
      );
      final executor = MockRequestExecutor();
      when(() => executor.execute(checkUser, variables: any(named: 'variables')))
          .thenAnswer((_) async => const ExecutedResponse(status: 404));

      await pumpRunView(tester, flow, executor: executor);

      await openRunTab(tester, 0, settle: settle);

      expect(find.text('Assertion Failure'), findsOneWidget);
      expect(find.textContaining('Assertion failed'), findsWidgets);
    });
  });

  group('assertions in the run view', () {
    testWidgets('a step with three assertions shows n/m, an Assertions tab with a mark each, and one error line per failure',
        (tester) async {
      await tester.runAsync(() async {
        final flow = Flow(
          id: 'f-1',
          name: 'Flow',
          steps: const [
            FlowStep(endpointId: 'e-1', assertions: [
              Assertion(field: 'response.status', expected: '200'),
              Assertion(field: 'response.body.id', operator: AssertionOperator.exists),
              Assertion(field: 'response.body.name', operator: AssertionOperator.exists),
            ]),
          ],
        );
        final executor = MockRequestExecutor();
        when(() => executor.execute(checkUser, variables: any(named: 'variables'))).thenAnswer(
          (_) async => const ExecutedResponse(status: 404, body: {'id': 'u-1'}, elapsedMs: 50),
        );

        await pumpRunView(tester, flow, executor: executor);

        expect(find.text('1/3 assertions'), findsOneWidget);
        // The failed step is auto-selected: its Error Details tab lists each failure on its own line.
        expect(find.byKey(const Key('error-line-0')), findsOneWidget);
        expect(find.byKey(const Key('error-line-1')), findsOneWidget);
        expect(find.byKey(const Key('error-line-2')), findsNothing);

        await tester.tap(find.text('Assertions'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assertion-result-0')), findsOneWidget);
        expect(find.byKey(const Key('assertion-passed-0')), findsNothing);
        expect(find.byKey(const Key('assertion-failed-0')), findsOneWidget);
        expect(find.byKey(const Key('assertion-passed-1')), findsOneWidget);
        expect(find.byKey(const Key('assertion-failed-2')), findsOneWidget);
        expect(find.textContaining('response.status == "200"'), findsWidgets);
        expect(find.textContaining('got "404"'), findsWidgets);
      });
    });

    testWidgets('a step that passes still lists what was checked', (tester) async {
      await tester.runAsync(() async {
        final flow = Flow(
          id: 'f-1',
          name: 'Flow',
          steps: const [
            FlowStep(endpointId: 'e-1', assertions: [
              Assertion(field: 'response.elapsedMs', operator: AssertionOperator.lessThan, expected: '800'),
            ]),
          ],
        );
        final executor = MockRequestExecutor();
        when(() => executor.execute(checkUser, variables: any(named: 'variables')))
            .thenAnswer((_) async => const ExecutedResponse(status: 200, elapsedMs: 50));

        await pumpRunView(tester, flow, executor: executor);

        expect(find.text('1/1 assertions'), findsOneWidget);
        expect(find.text('Error Details'), findsNothing);
        await tester.tap(find.text('Assertions'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('assertion-passed-0')), findsOneWidget);
      });
    });

    testWidgets('a step without assertions has no Assertions tab and no summary', (tester) async {
      await tester.runAsync(() async {
        final flow = Flow(id: 'f-1', name: 'Flow', steps: const [FlowStep(endpointId: 'e-1')]);
        final executor = MockRequestExecutor();
        when(() => executor.execute(checkUser, variables: any(named: 'variables')))
            .thenAnswer((_) async => const ExecutedResponse(status: 200));

        await pumpRunView(tester, flow, executor: executor);

        expect(find.text('Assertions'), findsNothing);
        expect(find.textContaining('assertions'), findsNothing);
      });
    });

    testWidgets('one failed assertion is one error line even when the actual value has line breaks', (tester) async {
      await tester.runAsync(() async {
        final flow = Flow(
          id: 'f-1',
          name: 'Flow',
          steps: const [
            FlowStep(endpointId: 'e-1', assertions: [Assertion(field: 'response.body', expected: 'x')]),
          ],
        );
        final executor = MockRequestExecutor();
        when(() => executor.execute(checkUser, variables: any(named: 'variables')))
            .thenAnswer((_) async => const ExecutedResponse(status: 200, body: 'line1\nline2'));

        await pumpRunView(tester, flow, executor: executor);

        expect(find.byKey(const Key('error-line-0')), findsOneWidget);
        expect(find.byKey(const Key('error-line-1')), findsNothing);
      });
    });

    testWidgets('an invalid path is a failed row with its message', (tester) async {
      await tester.runAsync(() async {
        final flow = Flow(
          id: 'f-1',
          name: 'Flow',
          steps: const [
            FlowStep(endpointId: 'e-1', assertions: [Assertion(field: 'body.id', operator: AssertionOperator.exists)]),
          ],
        );
        final executor = MockRequestExecutor();
        when(() => executor.execute(checkUser, variables: any(named: 'variables')))
            .thenAnswer((_) async => const ExecutedResponse(status: 200));

        await pumpRunView(tester, flow, executor: executor);
        await tester.tap(find.text('Assertions'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('assertion-failed-0')), findsOneWidget);
        expect(find.textContaining('Invalid field path "body.id"'), findsWidgets);
      });
    });
  });

  testWidgets('a skipped step cannot be expanded', (tester) async {
    await tester.runAsync(() async {
      final flow = Flow(
        id: 'f-1',
        name: 'Flow',
        steps: const [
          FlowStep(endpointId: 'e-1', assertions: [Assertion(field: 'response.status', expected: '200')]),
          FlowStep(endpointId: 'e-2'),
        ],
      );
      final executor = MockRequestExecutor();
      when(() => executor.execute(checkUser, variables: any(named: 'variables')))
          .thenAnswer((_) async => const ExecutedResponse(status: 404));

      await pumpRunView(tester, flow, executor: executor);

      await openRunTab(tester, 1, settle: settle);

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

      await openRunTab(tester, 1, settle: settle);
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
