import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/collections/sidebar_tree.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/request_builder/request_bar.dart';
import 'package:api_flow_studio/ui/request_builder/send_provider.dart';
import 'package:api_flow_studio/ui/response_viewer/response_panel.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:api_flow_studio/ui/workspace/workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

void main() {
  setUpAll(() => registerFallbackValue(FakeEndpoint()));

  late MockRequestExecutor executor;

  setUp(() => executor = MockRequestExecutor());

  Future<void> pumpWorkspace(WidgetTester tester, {required double width}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          requestExecutorProvider.overrideWithValue(executor),
          jsonStoreProvider.overrideWithValue(JsonStore.inMemory()),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: WorkspaceScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('at a wide window the sidebar, request and response sit side by side', (tester) async {
    await pumpWorkspace(tester, width: 1440);

    final sidebar = tester.getRect(find.byType(SidebarTree));
    final request = tester.getRect(find.byType(RequestBar));
    final response = tester.getRect(find.byType(ResponsePanel));

    expect(sidebar.width, 300);
    expect(request.left, greaterThanOrEqualTo(sidebar.right));
    expect(response.left, greaterThanOrEqualTo(request.right));
    expect(response.top, lessThan(request.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the response width is about 0.92 of the request width', (tester) async {
    await pumpWorkspace(tester, width: 1440);

    final request = tester.getSize(find.byKey(const Key('workspace-request-pane'))).width;
    final response = tester.getSize(find.byKey(const Key('workspace-response-pane'))).width;

    expect(response / request, closeTo(0.92, 0.02));
  });

  testWidgets('the response pane uses the response background color', (tester) async {
    await pumpWorkspace(tester, width: 1440);

    final pane = tester.widget<Container>(find.byKey(const Key('workspace-response-pane')));

    expect((pane.decoration! as BoxDecoration).color, AppColors.responseBackground);
  });

  testWidgets('below 1100px the response is stacked under the request', (tester) async {
    await pumpWorkspace(tester, width: 900);

    final sidebar = tester.getRect(find.byType(SidebarTree));
    final request = tester.getRect(find.byType(RequestBar));
    final response = tester.getRect(find.byType(ResponsePanel));

    expect(sidebar.width, 300);
    expect(response.top, greaterThanOrEqualTo(request.bottom));
    expect(response.left, lessThan(request.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the request builder no longer embeds the response panel', (tester) async {
    await pumpWorkspace(tester, width: 1440);

    expect(find.descendant(of: find.byType(RequestBar), matching: find.byType(ResponsePanel)), findsNothing);
  });

  testWidgets('sending a request shows its response in the right-hand pane', (tester) async {
    when(() => executor.execute(any(), variables: any(named: 'variables'))).thenAnswer(
      (_) async => const ExecutedResponse(status: 200, body: '{"ok":true}', elapsedMs: 42, sizeBytes: 11),
    );
    await pumpWorkspace(tester, width: 1440);

    await tester.enterText(find.byKey(const Key('request-url-field')), 'https://httpbin.org/get');
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    final pane = find.byKey(const Key('workspace-response-pane'));
    expect(find.descendant(of: pane, matching: find.textContaining('"ok"')), findsOneWidget);
    expect(find.descendant(of: pane, matching: find.text('200')), findsOneWidget);
  });
}
