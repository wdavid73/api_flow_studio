import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/collections/collections_provider.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/flows/canvas/step_panel.dart';
import 'package:api_flow_studio/ui/flows/flow_run_provider.dart';
import 'package:api_flow_studio/ui/flows/flows_provider.dart';
import 'package:api_flow_studio/ui/request_builder/request_executor_provider.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

void main() {
  setUpAll(() => registerFallbackValue(FakeEndpoint()));

  const login = Endpoint(id: 'e-login', groupId: 'g', name: 'Login', method: 'POST', url: '{{base_url}}/login');
  const me = Endpoint(
    id: 'e-me',
    groupId: 'g',
    name: 'Get user',
    method: 'GET',
    url: '{{base_url}}/users/{{user_id}}?region={{region}}&n={{\$uuid}}',
  );
  const home = Endpoint(id: 'e-home', groupId: 'g', name: 'Home', method: 'GET', url: '{{base_url}}/home');
  final endpoints = {login.id: login, me.id: me, home.id: home};
  const flow = Flow(
    id: 'f',
    name: 'Sign in',
    steps: [
      FlowStep(endpointId: 'e-login', extract: {'user_id': 'response.body.user.id'}),
      FlowStep(endpointId: 'e-me'),
    ],
  );

  late JsonStore store;
  late MockRequestExecutor executor;

  Future<ProviderContainer> pumpPanel(WidgetTester tester, {VoidCallback? onClose}) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    store = JsonStore.inMemory();
    executor = MockRequestExecutor();
    await store.writeEnvironments(const [
      Environment(id: 'dev', name: 'Dev', variables: {'base_url': EnvironmentVariable(value: 'https://api.dev')}),
    ]);
    await store.writeActiveEnvironmentId('dev');
    await store.writeCollections(groups: const [Group(id: 'g', name: 'Auth')], endpoints: [login, me, home]);
    await store.writeFlows(const [flow]);

    final container = ProviderContainer(overrides: [
      jsonStoreProvider.overrideWithValue(store),
      requestExecutorProvider.overrideWithValue(executor),
    ]);
    addTearDown(container.dispose);
    // The Flows screen keeps the collections loaded; the request picker reads them.
    container.listen(collectionsProvider, (_, _) {});

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              final current = ref.watch(flowsProvider).value?.firstOrNull;
              if (current == null || current.steps.length < 2) return const SizedBox();
              return StepPanel(flow: current, index: 1, endpoints: endpoints, onClose: onClose ?? () {});
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  Future<FlowStep> savedStep(int index) async => (await store.readFlows()).single.steps[index];

  testWidgets('the Step tab lists the inputs with their origin', (tester) async {
    await pumpPanel(tester);

    expect(find.byKey(const Key('step-panel')), findsOneWidget);
    for (final (name, origin) in [
      ('base_url', 'env'),
      ('user_id', '← Login'),
      ('region', '⚠ no source'),
      ('\$uuid', 'generated'),
    ]) {
      expect(
        find.descendant(of: find.byKey(Key('panel-input-$name')), matching: find.text(origin)),
        findsOneWidget,
        reason: name,
      );
    }
  });

  testWidgets('editing an extract, an assertion or stop on failure persists the step', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.byKey(const Key('add-extract-1')));
    await tester.pumpAndSettle();
    expect((await savedStep(1)).extract, {'variable': ''});

    await tester.ensureVisible(find.text('Add assertion'));
    await tester.tap(find.text('Add assertion'));
    await tester.pumpAndSettle();
    expect((await savedStep(1)).assertions, hasLength(1));

    await tester.ensureVisible(find.byKey(const Key('stop-on-failure-1')));
    await tester.tap(find.byKey(const Key('stop-on-failure-1')));
    await tester.pumpAndSettle();
    expect((await savedStep(1)).stopOnFailure, isFalse);
  });

  testWidgets('the Run tab only appears when the step has a run result', (tester) async {
    final container = await pumpPanel(tester);
    expect(find.byKey(const Key('step-panel-tab-run')), findsNothing);

    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 200, body: {'user': {'id': 'u1'}}));
    await tester.runAsync(() => container.read(flowRunProvider('f').notifier).runAll(flow, endpoints));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('step-panel-tab-run')));
    await tester.pumpAndSettle();
    expect(find.text('Request Sent'), findsOneWidget);
  });

  testWidgets('the Response tab shows the last response as a tappable tree', (tester) async {
    final container = await pumpPanel(tester);
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 200, body: {'plan': 'pro'}));
    await tester.runAsync(() => container.read(flowRunProvider('f').notifier).runAll(flow, endpoints));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('step-panel-tab-response')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('response-tree-value-response.body.plan')), findsOneWidget);
  });

  testWidgets('the Response tab without a response says it was not sent', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.byKey(const Key('step-panel-tab-response')));
    await tester.pumpAndSettle();

    expect(find.text('Not sent yet'), findsOneWidget);
  });

  testWidgets('change request points the step at another request and clears run results from it', (tester) async {
    final container = await pumpPanel(tester);
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 200));
    await tester.runAsync(() => container.read(flowRunProvider('f').notifier).runAll(flow, endpoints));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('step-panel-change-request')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-step-picker-item-e-home')));
    await tester.pumpAndSettle();

    expect((await savedStep(1)).endpointId, 'e-home');
    final results = container.read(flowRunProvider('f')).results;
    expect(results[0], isNotNull);
    expect(results[1], isNull);
  });

  testWidgets('delete removes the step and closes the panel', (tester) async {
    var closed = false;
    await pumpPanel(tester, onClose: () => closed = true);

    await tester.ensureVisible(find.byKey(const Key('step-panel-delete')));
    await tester.tap(find.byKey(const Key('step-panel-delete')));
    await tester.pumpAndSettle();

    expect((await store.readFlows()).single.steps, hasLength(1));
    expect(closed, isTrue);
  });

  testWidgets('the close button calls onClose', (tester) async {
    var closed = false;
    await pumpPanel(tester, onClose: () => closed = true);

    await tester.tap(find.byKey(const Key('step-panel-close')));
    expect(closed, isTrue);
  });
}
