import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/ui/flows/flows_screen.dart';
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

import 'canvas_run_harness.dart';

// Ported from flow_run_view_restyle_test.dart: the summary strip lives in the
// canvas toolbar, the step statuses on the nodes, the inspector in the side panel.

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

const _a = Endpoint(id: 'e-a', groupId: 'g-1', name: 'Check user', method: 'GET', url: 'https://x.test/a');
const _b = Endpoint(id: 'e-b', groupId: 'g-1', name: 'Send OTP', method: 'POST', url: 'https://x.test/b');
const _c = Endpoint(id: 'e-c', groupId: 'g-1', name: 'Create user', method: 'POST', url: 'https://x.test/c');

void main() {
  setUpAll(() => registerFallbackValue(FakeEndpoint()));

  // Step 1 passes (100 ms, 20 B), step 2 fails with a transport error (40 ms),
  // step 3 is skipped because the flow stops on failure.
  Future<ProviderContainer> pumpRun(WidgetTester tester) async {
    final executor = MockRequestExecutor();
    var call = 0;
    when(() => executor.execute(any(), variables: any(named: 'variables'))).thenAnswer((_) async {
      call++;
      return call == 1
          ? const ExecutedResponse(status: 200, body: {'ok': true}, elapsedMs: 100, sizeBytes: 20)
          : const ExecutedResponse(error: 'boom', elapsedMs: 40);
    });
    final app = await pumpCanvasRun(
      tester,
      theme: AppTheme.dark(),
      flow: const Flow(
        id: 'f-1',
        name: 'Sign up',
        steps: [FlowStep(endpointId: 'e-a'), FlowStep(endpointId: 'e-b'), FlowStep(endpointId: 'e-c')],
      ),
      endpoints: const {'e-a': _a, 'e-b': _b, 'e-c': _c},
      executor: executor,
    );
    return app.container;
  }

  Color? colorOf(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style?.color;
  Finder status(int i) => find.byKey(ValueKey('step-node-status-$i'));

  testWidgets('the summary strip counts and colors passed, failed and skipped steps', (tester) async {
    await pumpRun(tester);

    expect(colorOf(tester, '1 passed'), AppColors.tertiary);
    expect(colorOf(tester, '1 failed'), AppColors.error);
    expect(colorOf(tester, '1 skipped'), AppColors.outline);
  });

  testWidgets('the summary strip shows the total time of the steps that ran', (tester) async {
    await pumpRun(tester);

    expect(tester.widget<Text>(find.byKey(const Key('run-summary-total'))).data, '140 ms');
  });

  testWidgets('the failed step is selected with a primaryContainer border', (tester) async {
    final container = await pumpRun(tester);

    Material surface(int i) => tester.widget<Material>(
          find.descendant(of: find.byKey(ValueKey('step-node-$i')), matching: find.byType(Material)).first,
        );
    final shape = surface(1).shape! as RoundedRectangleBorder;

    expect(container.read(selectedStepIndexProvider), 1);
    expect(shape.side.color, AppColors.primaryContainer);
    expect(shape.borderRadius, BorderRadius.circular(AppRadius.xl));
    expect((surface(0).shape! as RoundedRectangleBorder).side.color, AppColors.outlineVariant);
  });

  testWidgets('node statuses: a status badge when it passed, an error mark when it failed, Skipped in outline', (tester) async {
    await pumpRun(tester);

    expect(find.descendant(of: status(0), matching: find.byType(StatusBadge)), findsOneWidget);
    expect(tester.widget<Icon>(find.descendant(of: status(1), matching: find.byType(Icon))).color, AppColors.error);
    expect(tester.widget<Text>(find.descendant(of: status(2), matching: find.text('Skipped'))).style?.color, AppColors.outline);
  });

  testWidgets('the inspector sits on the response background with a status line and pill tabs', (tester) async {
    await pumpRun(tester);
    await openRunTab(tester, 0);

    expect(tester.widget<Material>(find.byKey(const Key('run-inspector-surface'))).color, AppColors.responseBackground);
    expect(find.descendant(of: find.byKey(const Key('run-inspector-surface')), matching: find.byType(StatusBadge)), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('inspector-elapsed'))).data, '100 ms');
    expect(tester.widget<Text>(find.byKey(const Key('inspector-size'))).data, '20 B');
    expect(find.byType(PillTabBar), findsOneWidget);
  });

  testWidgets('the response body sits in a surfaceContainerLowest block', (tester) async {
    await pumpRun(tester);
    await openRunTab(tester, 0);
    await tester.tap(find.text('Response Body'));
    await tester.pumpAndSettle();

    final block = tester.widget<Container>(find.byKey(const Key('inspector-code-block')));
    final decoration = block.decoration! as BoxDecoration;

    expect(decoration.color, AppColors.surfaceContainerLowest);
    expect(decoration.borderRadius, BorderRadius.circular(AppRadius.xl));
  });

  testWidgets('Re-run From Step is a ghost button and the toolbar keeps its keys', (tester) async {
    await pumpRun(tester);
    await openRunTab(tester, 0);

    expect(tester.widget(find.byKey(const ValueKey('rerun-from-step-0'))), isA<HeaderGhostButton>());
    expect(find.text('Re-run From Step 1'), findsOneWidget);
    expect(find.byKey(const Key('run-flow-button')), findsOneWidget);
    expect(find.byKey(const Key('run-summary-strip')), findsOneWidget);
  });
}
