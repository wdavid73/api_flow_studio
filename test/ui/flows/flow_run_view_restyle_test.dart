import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/flows/flow_run_view_screen.dart';
import 'package:api_flow_studio/ui/request_builder/send_provider.dart';
import 'package:api_flow_studio/ui/shell/header_ghost_button.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_spacing.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:api_flow_studio/ui/theme/widgets/pill_tab_bar.dart';
import 'package:api_flow_studio/ui/theme/widgets/status_badge.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

const _a = Endpoint(id: 'e-a', groupId: 'g', name: 'Check user', method: 'GET', url: 'https://x.test/a');
const _b = Endpoint(id: 'e-b', groupId: 'g', name: 'Send OTP', method: 'POST', url: 'https://x.test/b');
const _c = Endpoint(id: 'e-c', groupId: 'g', name: 'Create user', method: 'POST', url: 'https://x.test/c');

void main() {
  setUpAll(() => registerFallbackValue(FakeEndpoint()));

  // Step 1 passes (100 ms, 20 B), step 2 fails with a transport error (40 ms),
  // step 3 is skipped because the flow stops on failure.
  Future<void> pumpRunView(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final executor = MockRequestExecutor();
    var call = 0;
    when(() => executor.execute(any(), variables: any(named: 'variables'))).thenAnswer((_) async {
      call++;
      return call == 1
          ? const ExecutedResponse(status: 200, body: {'ok': true}, elapsedMs: 100, sizeBytes: 20)
          : const ExecutedResponse(error: 'boom', elapsedMs: 40);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsonStoreProvider.overrideWithValue(JsonStore.inMemory()),
          requestExecutorProvider.overrideWithValue(executor),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: FlowRunViewScreen(
            flow: const Flow(
              id: 'f-1',
              name: 'Sign up',
              steps: [FlowStep(endpointId: 'e-a'), FlowStep(endpointId: 'e-b'), FlowStep(endpointId: 'e-c')],
            ),
            endpoints: const {'e-a': _a, 'e-b': _b, 'e-c': _c},
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Color? colorOf(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style?.color;

  testWidgets('the summary strip counts and colors passed, failed and skipped steps', (tester) async {
    await pumpRunView(tester);

    expect(colorOf(tester, '1 passed'), AppColors.tertiary);
    expect(colorOf(tester, '1 failed'), AppColors.error);
    expect(colorOf(tester, '1 skipped'), AppColors.outline);
  });

  testWidgets('the summary strip shows the total time of the steps that ran', (tester) async {
    await pumpRunView(tester);

    expect(tester.widget<Text>(find.byKey(const Key('run-summary-total'))).data, '140 ms');
  });

  testWidgets('the failed step is selected with a primary border on surfaceContainerHigh', (tester) async {
    await pumpRunView(tester);

    final card = tester.widget<Card>(find.byKey(const ValueKey('run-step-card-1')));
    final shape = card.shape! as RoundedRectangleBorder;

    expect(card.color, AppColors.surfaceContainerHigh);
    expect(shape.side.color, AppColors.primary);
    expect(shape.borderRadius, BorderRadius.circular(AppRadius.xl));
    expect(tester.widget<Card>(find.byKey(const ValueKey('run-step-card-0'))).color, isNull);
  });

  testWidgets('status icons are tertiary for passed, error for failed, outline for skipped', (tester) async {
    await pumpRunView(tester);

    Color iconColor(int i) => tester.widget<Icon>(find.byKey(ValueKey('run-step-status-icon-$i'))).color!;

    expect(iconColor(0), AppColors.tertiary);
    expect(iconColor(1), AppColors.error);
    expect(iconColor(2), AppColors.outline);
  });

  testWidgets('the inspector sits on the response background with a status line and pill tabs', (tester) async {
    await pumpRunView(tester);
    await tester.tap(find.byKey(const ValueKey('run-step-header-0')));
    await tester.pump();

    expect(tester.widget<Material>(find.byKey(const Key('run-inspector-surface'))).color, AppColors.responseBackground);
    expect(find.descendant(of: find.byKey(const Key('run-inspector-surface')), matching: find.byType(StatusBadge)), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('inspector-elapsed'))).data, '100 ms');
    expect(tester.widget<Text>(find.byKey(const Key('inspector-size'))).data, '20 B');
    expect(find.byType(PillTabBar), findsOneWidget);
  });

  testWidgets('the response body sits in a surfaceContainerLowest block', (tester) async {
    await pumpRunView(tester);
    await tester.tap(find.byKey(const ValueKey('run-step-header-0')));
    await tester.pump();
    await tester.tap(find.text('Response Body'));
    await tester.pumpAndSettle();

    final block = tester.widget<Container>(find.byKey(const Key('inspector-code-block')));
    final decoration = block.decoration! as BoxDecoration;

    expect(decoration.color, AppColors.surfaceContainerLowest);
    expect(decoration.borderRadius, BorderRadius.circular(AppRadius.xl));
  });

  testWidgets('Re-run From Step is a ghost button and the existing keys are unchanged', (tester) async {
    await pumpRunView(tester);
    await tester.tap(find.byKey(const ValueKey('run-step-header-0')));
    await tester.pump();

    expect(tester.widget(find.byKey(const ValueKey('rerun-from-step-0'))), isA<HeaderGhostButton>());
    expect(find.text('Re-run From Step 1'), findsOneWidget);
    expect(find.byKey(const Key('run-view-back-button')), findsOneWidget);
    expect(find.byKey(const Key('re-run-flow-button')), findsOneWidget);
    expect(find.byKey(const Key('run-summary-strip')), findsOneWidget);
  });
}
