import 'dart:async';

import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/request_builder/send_provider.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:api_flow_studio/ui/workspace/workspace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

void main() {
  setUpAll(() => registerFallbackValue(FakeEndpoint()));

  late MockRequestExecutor executor;

  setUp(() {
    executor = MockRequestExecutor();
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 200, body: '{}'));
  });

  Future<void> pumpWorkspace(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
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

  Future<void> chord(WidgetTester tester, LogicalKeyboardKey modifier, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pump();
  }

  int sendCount() => verify(() => executor.execute(any(), variables: any(named: 'variables'))).callCount;

  testWidgets('Ctrl+Enter sends exactly once', (tester) async {
    await pumpWorkspace(tester);

    await chord(tester, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(sendCount(), 1);
  });

  testWidgets('Cmd+Enter sends exactly once', (tester) async {
    await pumpWorkspace(tester);

    await chord(tester, LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(sendCount(), 1);
  });

  testWidgets('Ctrl+Enter still sends while typing in the URL field', (tester) async {
    await pumpWorkspace(tester);
    await tester.tap(find.byKey(const Key('request-url-field')));
    await tester.pump();

    await chord(tester, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(sendCount(), 1);
  });

  testWidgets('the shortcut does nothing while a send is already running', (tester) async {
    final gate = Completer<ExecutedResponse>();
    when(() => executor.execute(any(), variables: any(named: 'variables'))).thenAnswer((_) => gate.future);
    await pumpWorkspace(tester);

    await chord(tester, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.enter);
    await chord(tester, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.enter);

    expect(sendCount(), 1);

    gate.complete(const ExecutedResponse(status: 200));
    await tester.pumpAndSettle();
  });

  testWidgets('/ focuses the sidebar search field', (tester) async {
    await pumpWorkspace(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pump();

    final search = tester.widget<TextField>(find.byKey(const Key('sidebar-search-field')));
    expect(search.focusNode!.hasFocus, isTrue);
  });

  testWidgets('/ typed inside another text field does not steal focus', (tester) async {
    await pumpWorkspace(tester);
    await tester.tap(find.byKey(const Key('request-url-field')));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.pump();

    final search = tester.widget<TextField>(find.byKey(const Key('sidebar-search-field')));
    final url = tester.widget<TextField>(find.byKey(const Key('request-url-field')));
    expect(search.focusNode!.hasFocus, isFalse);
    expect(url.focusNode?.hasFocus ?? true, isTrue);
  });
}
