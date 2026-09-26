import 'package:api_flow_studio/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpDesktopApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: ApiFlowStudioApp()));
  }

  testWidgets('renders all 4 nav destinations', (tester) async {
    await pumpDesktopApp(tester);

    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Environments'), findsOneWidget);
    expect(find.text('Flows'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('starts on the Workspace destination showing the request builder', (tester) async {
    await pumpDesktopApp(tester);

    expect(find.byKey(const Key('request-url-field')), findsOneWidget);
  });

  testWidgets('tapping a nav destination switches the visible body', (tester) async {
    await pumpDesktopApp(tester);

    await tester.tap(find.text('Environments'));
    await tester.pump();

    expect(find.text('Environments placeholder'), findsOneWidget);
    expect(find.byKey(const Key('request-url-field')), findsNothing);
  });
}
