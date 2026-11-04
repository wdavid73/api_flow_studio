import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart' show jsonStoreProvider;
import 'package:api_flow_studio/ui/flows/canvas/canvas_metrics.dart';
import 'package:api_flow_studio/ui/flows/flows_screen.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The store is in memory: there is no real I/O to wait for, so pumpAndSettle is enough.

void main() {
  Future<void> settle(WidgetTester tester) => tester.pumpAndSettle();

  const login = Endpoint(
    id: 'e-login',
    groupId: 'g-1',
    name: 'Log in',
    method: 'POST',
    url: '{{base_url}}/login',
  );
  const me = Endpoint(id: 'e-me', groupId: 'g-1', name: 'Get user', method: 'GET', url: '{{base_url}}/users/{{user_id}}');
  const home = Endpoint(id: 'e-home', groupId: 'g-1', name: 'Home', method: 'GET', url: '{{base_url}}/home?r={{region}}');

  late JsonStore store;
  late ProviderContainer container;

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Flow> flows = const [],
    List<HistoryEntry> history = const [],
    String? select,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    store = JsonStore.inMemory();
    await store.writeEnvironments(const [
      Environment(id: 'dev', name: 'Dev', variables: {'base_url': EnvironmentVariable(value: 'https://api.dev')}),
    ]);
    await store.writeActiveEnvironmentId('dev');
    await store.writeCollections(
      groups: const [Group(id: 'g-1', name: 'Authentication API')],
      endpoints: const [login, me, home],
    );
    await store.writeFlows(flows);
    for (final entry in history) {
      await store.appendHistoryEntry(entry.endpointId, entry);
    }

    container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: FlowsScreen())),
    ));
    await settle(tester);
    if (select != null) {
      container.read(selectedFlowIdProvider.notifier).state = select;
      await settle(tester);
    }
  }

  Future<void> addStep(WidgetTester tester, String endpointId) async {
    await tester.tap(find.byKey(const Key('add-step-button')));
    await settle(tester);
    await tester.tap(find.byKey(Key('add-step-picker-item-$endpointId')));
    await settle(tester);
  }

  Future<void> nodeAction(WidgetTester tester, int index, String action) async {
    await tester.tap(find.byKey(Key('step-node-menu-$index')));
    await settle(tester);
    await tester.tap(find.byKey(Key('step-node-$action-$index')));
    await settle(tester);
  }

  const signIn = Flow(
    id: 'f-1',
    name: 'Sign in',
    steps: [
      FlowStep(endpointId: 'e-login', extract: {'user_id': 'response.body.user.id'}),
      FlowStep(endpointId: 'e-me'),
      FlowStep(endpointId: 'e-home'),
    ],
  );

  HistoryEntry loginResponse({DateTime? at, String? body, bool truncated = false}) => HistoryEntry(
        id: 'h-1',
        endpointId: 'e-login',
        timestamp: at ?? DateTime.now().subtract(const Duration(days: 3)),
        status: 200,
        body: body ?? '{"access_token": "tok", "user": {"id": "u_81f", "name": "Ana"}}',
        truncated: truncated,
      );

  Finder inNode(int index, Finder matching) => find.descendant(of: find.byKey(Key('step-node-$index')), matching: matching);

  testWidgets('shows an empty state with no flows yet', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(const Key('empty-flows-state')), findsOneWidget);
    expect(find.byKey(const Key('no-flow-selected')), findsOneWidget);
  });

  testWidgets('an empty flow shows the add-first-step node', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('new-flow-button')));
    await settle(tester);

    expect(find.byKey(const Key('empty-flow-state')), findsOneWidget);
    expect(find.text('Add first step'), findsOneWidget);
  });

  testWidgets('adding 3 steps shows 3 nodes left to right in step order and persists', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('new-flow-button')));
    await settle(tester);

    for (final id in ['e-login', 'e-me', 'e-home']) {
      await addStep(tester, id);
    }

    final x = [for (final i in [0, 1, 2]) tester.getTopLeft(find.byKey(Key('step-node-$i'))).dx];
    expect(x[0] < x[1] && x[1] < x[2], isTrue);
    expect(inNode(0, find.text('Log in')), findsOneWidget);
    expect(inNode(2, find.text('Home')), findsOneWidget);
    expect((await store.readFlows()).single.steps.map((s) => s.endpointId), ['e-login', 'e-me', 'e-home']);
  });

  testWidgets('a node shows its inputs with origin labels and its response fields', (tester) async {
    await pumpScreen(tester, flows: const [signIn], history: [loginResponse()], select: 'f-1');

    Finder origin(int i, String name) => find.byKey(Key('step-input-origin-$i-$name'));
    expect(find.descendant(of: origin(1, 'base_url'), matching: find.text('env')), findsOneWidget);
    expect(find.descendant(of: origin(1, 'user_id'), matching: find.text('← Log in')), findsOneWidget);
    expect(find.descendant(of: origin(2, 'region'), matching: find.text('⚠ no source')), findsOneWidget);
    expect(inNode(1, find.text('🔑 session')), findsOneWidget);

    expect(inNode(0, find.text('user.id')), findsOneWidget);
    expect(inNode(0, find.text('→ {{user_id}}')), findsOneWidget);
    expect(inNode(0, find.text('"Ana"')), findsOneWidget);
  });

  testWidgets('the response section names its source and age', (tester) async {
    await pumpScreen(tester, flows: const [signIn], history: [loginResponse()], select: 'f-1');

    expect(inNode(0, find.textContaining('history · 3 days ago')), findsOneWidget);
  });

  testWidgets('a token field is tagged 🔑 → session when captureTokens is on', (tester) async {
    await pumpScreen(tester, flows: const [signIn], history: [loginResponse()], select: 'f-1');

    expect(inNode(0, find.text('🔑 → session')), findsOneWidget);
  });

  testWidgets('a truncated or non-JSON history response shows its message and no fields', (tester) async {
    await pumpScreen(
      tester,
      flows: const [signIn],
      history: [loginResponse(body: '{"user": {"id": ', truncated: true)],
      select: 'f-1',
    );
    expect(inNode(0, find.text('Response was cut: run the step to see all of it')), findsOneWidget);
    expect(find.byKey(const Key('step-field-0-0')), findsNothing);

    await pumpScreen(tester, flows: const [signIn], history: [loginResponse(body: '<html>oops</html>')], select: 'f-1');
    expect(inNode(0, find.text('The response is not JSON')), findsOneWidget);
  });

  testWidgets('a node without a response shows Not sent yet', (tester) async {
    await pumpScreen(tester, flows: const [signIn], select: 'f-1');

    expect(inNode(1, find.text('Not sent yet')), findsOneWidget);
  });

  testWidgets('pins sit where canvas_metrics says', (tester) async {
    await pumpScreen(tester, flows: const [signIn], history: [loginResponse()], select: 'f-1');

    final origin = tester.getTopLeft(find.byKey(const Key('flow-canvas-content')));
    // Node 0 (Log in): inputs base_url and the session row.
    final expected = origin + Offset(nodeLeft(0) + nodeWidth, canvasPadding + fieldRowCenterY(2, 1));
    final pin = tester.getCenter(find.byKey(const Key('step-field-pin-0-1')));

    expect((pin - expected).distance, lessThan(1));
  });

  testWidgets('change request from the node menu keeps the step settings', (tester) async {
    await pumpScreen(tester, flows: const [
      Flow(id: 'f-1', name: 'One', steps: [FlowStep(endpointId: 'e-login', stopOnFailure: false)]),
    ], select: 'f-1');

    await nodeAction(tester, 0, 'change-request');
    await tester.tap(find.byKey(const Key('add-step-picker-item-e-me')));
    await settle(tester);

    final step = (await store.readFlows()).single.steps.single;
    expect(step.endpointId, 'e-me');
    expect(step.stopOnFailure, isFalse);
    expect(inNode(0, find.text('Get user')), findsOneWidget);
  });

  testWidgets('moving right and left from the node menu reorders and persists', (tester) async {
    await pumpScreen(tester, flows: const [signIn], select: 'f-1');

    await nodeAction(tester, 0, 'move-right');
    expect((await store.readFlows()).single.steps.map((s) => s.endpointId), ['e-me', 'e-login', 'e-home']);

    await nodeAction(tester, 2, 'move-left');
    expect((await store.readFlows()).single.steps.map((s) => s.endpointId), ['e-me', 'e-home', 'e-login']);
  });

  testWidgets('after a move an input whose extract is now later has no source', (tester) async {
    await pumpScreen(tester, flows: const [signIn], select: 'f-1');

    await nodeAction(tester, 0, 'move-right'); // Get user now comes before Log in

    expect(
      find.descendant(of: find.byKey(const Key('step-input-origin-0-user_id')), matching: find.text('⚠ no source')),
      findsOneWidget,
    );
  });

  testWidgets('deleting a step from the node menu persists', (tester) async {
    await pumpScreen(tester, flows: const [
      Flow(id: 'f-1', name: 'One', steps: [FlowStep(endpointId: 'e-login')]),
    ], select: 'f-1');

    await nodeAction(tester, 0, 'delete');

    expect(find.byKey(const Key('empty-flow-state')), findsOneWidget);
    expect((await store.readFlows()).single.steps, isEmpty);
  });

  testWidgets('a step whose request was deleted shows Request not found and can change request', (tester) async {
    await pumpScreen(tester, flows: const [
      Flow(id: 'f-1', name: 'One', steps: [FlowStep(endpointId: 'e-gone')]),
    ], select: 'f-1');

    expect(find.byKey(const Key('step-node-missing-0')), findsOneWidget);
    expect(find.text('Request not found'), findsOneWidget);

    await nodeAction(tester, 0, 'change-request');
    await tester.tap(find.byKey(const Key('add-step-picker-item-e-home')));
    await settle(tester);

    expect((await store.readFlows()).single.steps.single.endpointId, 'e-home');
  });

  testWidgets('selecting a node opens the side panel and closing it clears the selection', (tester) async {
    await pumpScreen(tester, flows: const [signIn], select: 'f-1');

    await tester.tap(inNode(1, find.text('Get user')));
    await settle(tester);
    expect(find.byKey(const Key('step-panel')), findsOneWidget);
    expect(container.read(selectedStepIndexProvider), 1);

    await tester.tap(find.byKey(const Key('step-panel-close')));
    await settle(tester);
    expect(find.byKey(const Key('step-panel')), findsNothing);
    expect(container.read(selectedStepIndexProvider), isNull);
  });

  testWidgets('zoom buttons change the level between 50% and 150%, and Fit fits the row', (tester) async {
    await pumpScreen(tester, flows: const [signIn], select: 'f-1');
    String level() => tester.widget<Text>(find.byKey(const Key('zoom-level'))).data!;

    expect(level(), '100%');
    await tester.tap(find.byKey(const Key('zoom-in')));
    await settle(tester);
    expect(level(), '110%');

    for (var i = 0; i < 12; i++) {
      await tester.tap(find.byKey(const Key('zoom-out')));
      await tester.pump();
    }
    await settle(tester);
    expect(level(), '50%');

    await tester.tap(find.byKey(const Key('zoom-fit')));
    await settle(tester);
    final percent = int.parse(level().replaceAll('%', ''));
    expect(percent, inInclusiveRange(50, 150));
    expect(percent, isNot(50));
  });

  testWidgets('renaming a flow persists the new name', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('new-flow-button')));
    await settle(tester);

    await tester.enterText(find.byKey(const Key('flow-name-field')), 'User Registration Flow');
    await settle(tester);

    expect((await store.readFlows()).single.name, 'User Registration Flow');
  });

  testWidgets('switching flows shows the other flow name', (tester) async {
    await pumpScreen(tester, flows: const [signIn, Flow(id: 'f-2', name: 'Checkout')], select: 'f-1');

    container.read(selectedFlowIdProvider.notifier).state = 'f-2';
    await settle(tester);

    final name = tester.widget<EditableText>(
      find.descendant(of: find.byKey(const Key('flow-name-field')), matching: find.byType(EditableText)),
    );
    expect(name.controller.text, 'Checkout');
  });

  testWidgets('deleting the selected flow removes it, persists, and clears the builder', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('new-flow-button')));
    await settle(tester);
    final flowId = (await store.readFlows()).single.id;

    await tester.tap(find.byKey(Key('delete-flow-$flowId')));
    await settle(tester);

    expect(find.byKey(const Key('no-flow-selected')), findsOneWidget);
    expect(await store.readFlows(), isEmpty);
  });

  testWidgets('the disabled Save button is gone', (tester) async {
    await pumpScreen(tester, flows: const [signIn], select: 'f-1');

    expect(find.byKey(const Key('save-flow-button')), findsNothing);
  });

  testWidgets('the flow list folds away and comes back', (tester) async {
    await pumpScreen(tester, flows: const [signIn], select: 'f-1');
    expect(find.byKey(const Key('list-detail-list-panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggle-flow-list')));
    await settle(tester);
    expect(find.byKey(const Key('list-detail-list-panel')), findsNothing);
    expect(find.byKey(const Key('flow-canvas')), findsOneWidget);

    await tester.tap(find.byKey(const Key('toggle-flow-list')));
    await settle(tester);
    expect(find.byKey(const Key('list-detail-list-panel')), findsOneWidget);
  });
}
