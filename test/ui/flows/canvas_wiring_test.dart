import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart' show jsonStoreProvider;
import 'package:api_flow_studio/ui/flows/flows_screen.dart';
import 'package:api_flow_studio/ui/shell/app_toast.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const login = Endpoint(id: 'e-login', groupId: 'g', name: 'Log in', method: 'POST', url: '/login');
  const middle = Endpoint(id: 'e-mid', groupId: 'g', name: 'Middle', method: 'GET', url: '/mid');
  const me = Endpoint(id: 'e-me', groupId: 'g', name: 'Get user', method: 'GET', url: '/users/{{user_id}}');
  const orders = Endpoint(id: 'e-orders', groupId: 'g', name: 'Orders', method: 'GET', url: '/orders?u={{user_id}}');

  late JsonStore store;
  late ProviderContainer container;

  Future<void> pumpCanvas(WidgetTester tester, Flow flow) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    store = JsonStore.inMemory();
    await store.writeCollections(groups: const [Group(id: 'g', name: 'G')], endpoints: const [login, middle, me, orders]);
    await store.writeFlows([flow]);
    await store.appendHistoryEntry(
      'e-login',
      HistoryEntry(
        id: 'h',
        endpointId: 'e-login',
        timestamp: DateTime(2026),
        status: 200,
        body: '{"token": "t", "user": {"id": "u_81f"}}',
      ),
    );
    container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: FlowsScreen())),
    ));
    await tester.pumpAndSettle();
    container.read(selectedFlowIdProvider.notifier).state = flow.id;
    await tester.pumpAndSettle();
  }

  /// Drags the pin of field [field] of step [from] and drops it on [target].
  Future<void> dragPin(WidgetTester tester, int from, int field, Finder target) async {
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(ValueKey('step-field-pin-$from-$field'))));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(target));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Future<FlowStep> saved(int index) async => (await store.readFlows()).single.steps[index];

  testWidgets('dragging a field pin onto a later input saves the extract and draws the wire', (tester) async {
    await pumpCanvas(tester, const Flow(id: 'f', name: 'F', steps: [
      FlowStep(endpointId: 'e-login'),
      FlowStep(endpointId: 'e-me'),
    ]));
    expect(find.byKey(const ValueKey('wire-0-1-user_id')), findsNothing);

    // Fields of Log in: token (0), user.id (1).
    await dragPin(tester, 0, 1, find.byKey(const ValueKey('step-input-1-user_id')));

    expect((await saved(0)).extract, {'user_id': 'response.body.user.id'});
    expect(find.byKey(const ValueKey('wire-0-1-user_id')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const ValueKey('step-input-origin-1-user_id')), matching: find.text('← Log in')),
      findsOneWidget,
    );
  });

  testWidgets('while dragging, only inputs of later steps are highlighted as targets', (tester) async {
    await pumpCanvas(tester, const Flow(id: 'f', name: 'F', steps: [
      FlowStep(endpointId: 'e-me'),
      FlowStep(endpointId: 'e-login'),
      FlowStep(endpointId: 'e-orders'),
    ]));

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('step-field-pin-1-1'))));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();

    expect(find.byKey(const ValueKey('drop-target-2-user_id')), findsOneWidget);
    expect(find.byKey(const ValueKey('drop-target-0-user_id')), findsNothing);

    // Dropping on the earlier step does nothing.
    await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('step-input-0-user_id'))));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect((await saved(1)).extract, isEmpty);
  });

  testWidgets('a shadowed drop is refused with a message and nothing changes', (tester) async {
    await pumpCanvas(tester, const Flow(id: 'f', name: 'F', steps: [
      FlowStep(endpointId: 'e-login'),
      FlowStep(endpointId: 'e-mid', extract: {'user_id': 'response.body.other'}),
      FlowStep(endpointId: 'e-me'),
    ]));

    await dragPin(tester, 0, 1, find.byKey(const ValueKey('step-input-2-user_id')));

    expect((await saved(0)).extract, isEmpty);
    expect(container.read(toastProvider), contains('already sets {{user_id}}'));
    await tester.pump(toastDuration); // let the toast go away
  });

  testWidgets('disconnect from the input origin label removes the extract and says how many steps use it', (tester) async {
    await pumpCanvas(tester, const Flow(id: 'f', name: 'F', steps: [
      FlowStep(endpointId: 'e-login', extract: {'user_id': 'response.body.user.id'}),
      FlowStep(endpointId: 'e-me'),
      FlowStep(endpointId: 'e-orders'),
    ]));
    expect(find.byKey(const ValueKey('wire-0-1-user_id')), findsOneWidget);
    expect(find.byKey(const ValueKey('wire-0-2-user_id')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('step-input-origin-1-user_id')));
    await tester.pumpAndSettle();
    expect(find.textContaining('used by 2 steps'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('disconnect-1-user_id')));
    await tester.pumpAndSettle();

    expect((await saved(0)).extract, isEmpty);
    expect(find.byKey(const ValueKey('wire-0-1-user_id')), findsNothing);
  });
}
