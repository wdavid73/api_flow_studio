import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart' show jsonStoreProvider;
import 'package:api_flow_studio/ui/flows/flows_screen.dart';
import 'package:api_flow_studio/ui/shell/app_toast.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const login = Endpoint(id: 'e-login', groupId: 'g', name: 'Log in', method: 'POST', url: '/login');
  const me = Endpoint(id: 'e-me', groupId: 'g', name: 'Get user', method: 'GET', url: '/users/me');
  const home = Endpoint(id: 'e-home', groupId: 'g', name: 'Home', method: 'GET', url: '/home?r={{region}}');

  late JsonStore store;
  late ProviderContainer container;

  Future<void> pumpCanvas(WidgetTester tester, Flow flow) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    store = JsonStore.inMemory();
    await store.writeCollections(groups: const [Group(id: 'g', name: 'G')], endpoints: const [login, me, home]);
    await store.writeFlows([flow]);
    await store.appendHistoryEntry(
      'e-login',
      HistoryEntry(id: 'h1', endpointId: 'e-login', timestamp: DateTime(2026), status: 200, body: '{"token": "t", "user": {"id": "u_81f"}}'),
    );
    await store.appendHistoryEntry(
      'e-me',
      HistoryEntry(id: 'h2', endpointId: 'e-me', timestamp: DateTime(2026), status: 200, body: '{"data": {"plan": "pro", "region": "co"}}'),
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

  Future<void> openFieldMenu(WidgetTester tester, int step, int field) async {
    await tester.tap(find.byKey(ValueKey('step-field-$step-$field')));
    await tester.pumpAndSettle();
  }

  Future<FlowStep> saved(int index) async => (await store.readFlows()).single.steps[index];

  const twoSteps = Flow(id: 'f', name: 'F', steps: [FlowStep(endpointId: 'e-login'), FlowStep(endpointId: 'e-me')]);

  testWidgets('Use as variable proposes the suggested name and saves the extract', (tester) async {
    await pumpCanvas(tester, twoSteps);

    await openFieldMenu(tester, 0, 1); // user.id
    await tester.tap(find.byKey(const Key('field-menu-use-as-variable')));
    await tester.pumpAndSettle();

    final name = tester.widget<EditableText>(
      find.descendant(of: find.byKey(const Key('variable-name-field')), matching: find.byType(EditableText)),
    );
    expect(name.controller.text, 'user_id');
    await tester.tap(find.byKey(const Key('variable-name-confirm')));
    await tester.pumpAndSettle();

    expect((await saved(0)).extract, {'user_id': 'response.body.user.id'});
  });

  testWidgets('an invalid name disables confirm and explains why', (tester) async {
    await pumpCanvas(tester, twoSteps);
    await openFieldMenu(tester, 0, 1);
    await tester.tap(find.byKey(const Key('field-menu-use-as-variable')));
    await tester.pumpAndSettle();

    for (final name in ['', 'user id', 'user-id']) {
      await tester.enterText(find.byKey(const Key('variable-name-field')), name);
      await tester.pump();

      expect(tester.widget<TextButton>(find.byKey(const Key('variable-name-confirm'))).onPressed, isNull, reason: name);
      expect(find.text('Use only letters, numbers and _'), findsOneWidget, reason: name);
    }
  });

  testWidgets('Add assertion appends an exists assertion and opens the panel on the step', (tester) async {
    await pumpCanvas(tester, twoSteps);

    await openFieldMenu(tester, 0, 1);
    await tester.tap(find.byKey(const Key('field-menu-add-assertion')));
    await tester.pumpAndSettle();

    expect((await saved(0)).assertions, [
      const Assertion(field: 'response.body.user.id', operator: AssertionOperator.exists),
    ]);
    expect(container.read(selectedStepIndexProvider), 0);
    expect(find.byKey(const Key('step-panel')), findsOneWidget);
    expect(find.byKey(const Key('assertion-field-0-0')), findsOneWidget);
  });

  testWidgets('Copy path puts the full path on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpCanvas(tester, twoSteps);

    await openFieldMenu(tester, 0, 1);
    await tester.tap(find.byKey(const Key('field-menu-copy-path')));
    await tester.pumpAndSettle();

    expect(copied, 'response.body.user.id');
    expect(container.read(toastProvider), 'Path copied');
    await tester.pump(toastDuration);
  });

  testWidgets('tapping a value in the panel response tree opens the same menu', (tester) async {
    await pumpCanvas(tester, twoSteps);
    container.read(selectedStepIndexProvider.notifier).state = 1;
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('step-panel-tab-response')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('response-tree-value-response.body.data.plan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('field-menu-use-as-variable')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('variable-name-confirm')));
    await tester.pumpAndSettle();

    expect((await saved(1)).extract, {'plan': 'response.body.data.plan'});
  });

  testWidgets('a missing input with a matching field shows a suggestion that connects on tap', (tester) async {
    await pumpCanvas(tester, const Flow(id: 'f', name: 'F', steps: [
      FlowStep(endpointId: 'e-login'),
      FlowStep(endpointId: 'e-me'),
      FlowStep(endpointId: 'e-home'),
    ]));

    expect(find.text('Connect region?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('suggestion-2-region')));
    await tester.pumpAndSettle();

    expect((await saved(1)).extract, {'region': 'response.body.data.region'});
    expect(find.byKey(const ValueKey('suggestion-2-region')), findsNothing);
    expect(find.byKey(const ValueKey('wire-1-2-region')), findsOneWidget);
  });
}
