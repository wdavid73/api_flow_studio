import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/collections/method_filter_chips.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/flows/flows_screen.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:api_flow_studio/ui/theme/widgets/method_badge.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _get = Endpoint(id: 'e-get', groupId: 'g-1', name: 'Check user', method: 'GET', url: 'https://x.test/a');
const _post = Endpoint(id: 'e-post', groupId: 'g-1', name: 'Send OTP', method: 'POST', url: 'https://x.test/b');

void main() {
  Future<void> openPicker(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = JsonStore.inMemory();
    await store.writeCollections(groups: const [Group(id: 'g-1', name: 'API')], endpoints: const [_get, _post]);
    await store.writeFlows(const [Flow(id: 'f-1', name: 'Sign up')]);
    final container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: FlowsScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();
    container.read(selectedFlowIdProvider.notifier).state = 'f-1';
    await tester.pump();
    await tester.tap(find.byKey(const Key('add-step-button')));
    await tester.pumpAndSettle();
  }

  Finder chip(String method) => find.byKey(ValueKey('add-step-picker-method-chip-$method'));

  Container body(WidgetTester tester, String method) =>
      tester.widget<Container>(find.descendant(of: chip(method), matching: find.byType(Container)).first);

  Color? label(WidgetTester tester, String method) =>
      tester.widget<Text>(find.descendant(of: chip(method), matching: find.text(method))).style?.color;

  testWidgets('the picker method chips are the same MethodChip widget the sidebar uses', (tester) async {
    await openPicker(tester);

    expect(find.descendant(of: find.byType(AlertDialog), matching: find.byType(MethodChip)), findsNWidgets(2));
  });

  testWidgets('an inactive chip is outlined with its verb color', (tester) async {
    await openPicker(tester);

    final decoration = body(tester, 'GET').decoration! as BoxDecoration;

    expect(decoration.color, isNull);
    expect((decoration.border! as Border).top.color, AppColors.outlineVariant);
    expect(label(tester, 'GET'), MethodBadge.colorForMethod('GET'));
  });

  testWidgets('tapping a chip fills it with onSurface, like the active sidebar chip, and filters', (tester) async {
    await openPicker(tester);

    await tester.tap(chip('GET'));
    await tester.pump();

    final decoration = body(tester, 'GET').decoration! as BoxDecoration;
    expect(decoration.color, AppColors.onSurface);
    expect(label(tester, 'GET'), AppColors.surface);
    expect(find.byKey(const ValueKey('add-step-picker-item-e-get')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-step-picker-item-e-post')), findsNothing);
  });

  testWidgets('the picker still allows several methods at once and tapping again clears one', (tester) async {
    await openPicker(tester);

    await tester.tap(chip('GET'));
    await tester.tap(chip('POST'));
    await tester.pump();
    expect(find.byKey(const ValueKey('add-step-picker-item-e-get')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-step-picker-item-e-post')), findsOneWidget);

    await tester.tap(chip('GET'));
    await tester.pump();
    expect(find.byKey(const ValueKey('add-step-picker-item-e-get')), findsNothing);
    expect(find.byKey(const ValueKey('add-step-picker-item-e-post')), findsOneWidget);
  });
}
