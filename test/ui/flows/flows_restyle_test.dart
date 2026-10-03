import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/flows/flows_screen.dart';
import 'package:api_flow_studio/ui/shell/header_ghost_button.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:api_flow_studio/ui/theme/app_typography.dart';
import 'package:api_flow_studio/ui/theme/widgets/method_badge.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _checkUser = Endpoint(id: 'e-1', groupId: 'g-1', name: 'Check user', method: 'GET', url: 'https://x.test/exists');
const _sendOtp = Endpoint(id: 'e-2', groupId: 'g-1', name: 'Send OTP', method: 'POST', url: 'https://x.test/otp');

const _signup = Flow(
  id: 'f-1',
  name: 'Sign up',
  steps: [FlowStep(endpointId: 'e-1'), FlowStep(endpointId: 'e-2')],
);
const _login = Flow(id: 'f-2', name: 'Log in');

void main() {
  late ProviderContainer container;

  Future<void> pumpFlows(WidgetTester tester, {List<Flow> flows = const [_signup, _login]}) async {
    tester.view.physicalSize = const Size(1600, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = JsonStore.inMemory();
    await store.writeCollections(groups: const [Group(id: 'g-1', name: 'API')], endpoints: const [_checkUser, _sendOtp]);
    await store.writeFlows(flows);
    container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: FlowsScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Color? fill(WidgetTester tester, String id) => tester.widget<Material>(find.byKey(Key('flow-row-surface-$id'))).color;

  testWidgets('the list panel is 300px with the FLOWS kicker and a ghost New flow button', (tester) async {
    await pumpFlows(tester);

    expect(tester.getSize(find.byKey(const Key('list-detail-list-panel'))).width, 300);
    expect(find.text('FLOWS'), findsOneWidget);
    expect(tester.widget(find.byKey(const Key('new-flow-button'))), isA<HeaderGhostButton>());
    expect(find.text('New flow'), findsOneWidget);
  });

  testWidgets('rows show the name and step count, the selected one on surfaceContainerHigh', (tester) async {
    await pumpFlows(tester);
    container.read(selectedFlowIdProvider.notifier).state = 'f-1';
    await tester.pump();

    expect(find.descendant(of: find.byKey(const ValueKey('flow-list-item-f-1')), matching: find.text('Sign up')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('flow-list-item-f-1')), matching: find.text('2 steps')), findsOneWidget);
    expect(fill(tester, 'f-1'), AppColors.surfaceContainerHigh);
    expect(fill(tester, 'f-2'), Colors.transparent);

    await tester.tap(find.byKey(const ValueKey('flow-list-item-f-2')));
    await tester.pump();

    expect(container.read(selectedFlowIdProvider), 'f-2');
    expect(fill(tester, 'f-2'), AppColors.surfaceContainerHigh);
    expect(fill(tester, 'f-1'), Colors.transparent);
  });

  testWidgets('the builder titles the flow in the title style, with a lime Run and an outlined Save', (tester) async {
    await pumpFlows(tester);
    container.read(selectedFlowIdProvider.notifier).state = 'f-1';
    await tester.pump();

    final name = tester.widget<EditableText>(find.descendant(of: find.byKey(const Key('flow-name-field')), matching: find.byType(EditableText)));
    expect(name.style.fontSize, AppTypography.title.fontSize);
    expect(tester.widget(find.byKey(const Key('run-flow-button'))), isA<FilledButton>());
    expect(tester.widget(find.byKey(const Key('save-flow-button'))), isA<OutlinedButton>());
  });

  testWidgets('Add step is a ghost button at the end of the pipeline', (tester) async {
    await pumpFlows(tester);
    container.read(selectedFlowIdProvider.notifier).state = 'f-1';
    await tester.pump();

    expect(tester.widget(find.byKey(const Key('add-step-button'))), isA<HeaderGhostButton>());
    expect(find.text('Add Next Step to Pipeline'), findsOneWidget);
  });

  testWidgets('step cards show the method, name and a monospace url', (tester) async {
    await pumpFlows(tester);
    container.read(selectedFlowIdProvider.notifier).state = 'f-1';
    await tester.pump();

    final card = find.byKey(const ValueKey('step-card-0'));
    expect(find.descendant(of: card, matching: find.byType(MethodBadge)), findsOneWidget);
    expect(find.descendant(of: card, matching: find.text('Check user')), findsOneWidget);
    final url = tester.widget<Text>(find.descendant(of: card, matching: find.text('https://x.test/exists')));
    expect(url.style?.fontFamily, AppTypography.codeFontFamily);
  });

  testWidgets('empty states keep their text and keys', (tester) async {
    await pumpFlows(tester, flows: const []);

    expect(find.byKey(const Key('empty-flows-state')), findsOneWidget);
    expect(find.byKey(const Key('no-flow-selected')), findsOneWidget);
  });
}
