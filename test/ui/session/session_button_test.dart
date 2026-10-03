import 'dart:convert';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/session/session.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/session/session_button.dart';
import 'package:api_flow_studio/ui/session/session_provider.dart';
import 'package:api_flow_studio/ui/shell/app_header.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String jwt(Map<String, Object?> claims) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.sig';
}

void main() {
  late ProviderContainer container;
  var clock = DateTime.utc(2026, 10, 2, 12);

  int secs(Duration fromNow) => clock.add(fromNow).millisecondsSinceEpoch ~/ 1000;

  Future<void> pumpButton(
    WidgetTester tester, {
    List<Environment> environments = const [Environment(id: 'a', name: 'Dev'), Environment(id: 'b', name: 'QA')],
    String? activeId = 'a',
    bool inHeader = false,
    bool competingFocus = false,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    clock = DateTime.utc(2026, 10, 2, 12);

    final store = JsonStore.inMemory();
    await store.writeEnvironments(environments);
    await store.writeActiveEnvironmentId(activeId);
    container = ProviderContainer(overrides: [
      jsonStoreProvider.overrideWithValue(store),
      sessionClockProvider.overrideWithValue(() => clock),
    ]);
    addTearDown(container.dispose);
    await container.read(environmentsProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          // The real app already has a focused widget (WorkspaceShortcuts
          // autofocuses itself) before the popover opens.
          home: Focus(
            autofocus: competingFocus,
            child: Scaffold(
            body: inHeader
                ? const Column(children: [AppHeader(actions: [SessionButton()])])
                : const Align(alignment: Alignment.topRight, child: SessionButton()),
          ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  void setSession(Session session, {String key = 'a'}) =>
      container.read(sessionsProvider.notifier).update(key, session);

  Color? colorOf(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style?.color;

  group('button', () {
    testWidgets('without a token it says so, in the on-surface color', (tester) async {
      await pumpButton(tester);

      expect(find.text('No token'), findsOneWidget);
      expect(find.text('kept in memory only'), findsOneWidget);
      expect(colorOf(tester, 'No token'), AppColors.onSurface);
    });

    testWidgets('with a valid JWT it shows the time left in the tertiary color', (tester) async {
      await pumpButton(tester);
      setSession(Session(accessToken: jwt({'exp': secs(const Duration(minutes: 12))})));
      await tester.pump();

      expect(find.text('Expires in 12 min'), findsOneWidget);
      expect(find.text('Authorization: Bearer'), findsOneWidget);
      expect(colorOf(tester, 'Expires in 12 min'), AppColors.tertiary);
    });

    testWidgets('with an expired JWT it says Token expired in the warning color', (tester) async {
      await pumpButton(tester);
      setSession(Session(accessToken: jwt({'exp': secs(const Duration(minutes: -3))})));
      await tester.pump();

      expect(colorOf(tester, 'Token expired'), AppColors.warning);
    });

    testWidgets('a token that is not a JWT reads Token saved', (tester) async {
      await pumpButton(tester);
      setSession(const Session(accessToken: 'opaque'));
      await tester.pump();

      expect(find.text('Token saved'), findsOneWidget);
    });

    testWidgets('it shows the session of the active environment and follows a switch', (tester) async {
      await pumpButton(tester);
      setSession(const Session(accessToken: 'opaque'), key: 'a');

      await tester.pump();
      expect(find.text('Token saved'), findsOneWidget);

      await container.read(environmentsProvider.notifier).setActive('b');
      await tester.pump();
      await tester.pump();

      expect(find.text('No token'), findsOneWidget);
    });

    testWidgets('the label refreshes as time passes', (tester) async {
      await pumpButton(tester);
      setSession(Session(accessToken: jwt({'exp': secs(const Duration(minutes: 2))})));
      await tester.pump();
      expect(find.text('Expires in 2 min'), findsOneWidget);

      clock = clock.add(const Duration(minutes: 3));
      await tester.pump(const Duration(seconds: 31));

      expect(find.text('Token expired'), findsOneWidget);
    });

    testWidgets('it sits in the header actions zone', (tester) async {
      await pumpButton(tester, inHeader: true);

      expect(
        find.descendant(of: find.byType(AppHeader), matching: find.byKey(const Key('session-button'))),
        findsOneWidget,
      );
    });

    testWidgets('the button never shows the token itself', (tester) async {
      await pumpButton(tester);
      setSession(const Session(accessToken: 'super-secret-value'));
      await tester.pump();

      expect(find.textContaining('super-secret-value'), findsNothing);
    });
  });

  group('popover shell', () {
    testWidgets('is closed at first, opens on tap and closes on a second tap', (tester) async {
      await pumpButton(tester);
      expect(find.byKey(const Key('session-popover')), findsNothing);

      await tester.tap(find.byKey(const Key('session-button')));
      await tester.pump();
      expect(find.byKey(const Key('session-popover')), findsOneWidget);

      await tester.tap(find.byKey(const Key('session-button')), warnIfMissed: false);
      await tester.pump();
      expect(find.byKey(const Key('session-popover')), findsNothing);
    });

    testWidgets('Esc closes it', (tester) async {
      await pumpButton(tester);
      await tester.tap(find.byKey(const Key('session-button')));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byKey(const Key('session-popover')), findsNothing);
    });

    testWidgets('Esc closes it even when something else in the app already has focus', (tester) async {
      await pumpButton(tester, competingFocus: true);
      await tester.tap(find.byKey(const Key('session-button')));
      await tester.pump();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byKey(const Key('session-popover')), findsNothing);
    });

    testWidgets('a click outside closes it', (tester) async {
      await pumpButton(tester);
      await tester.tap(find.byKey(const Key('session-button')));
      await tester.pump();

      await tester.tapAt(const Offset(100, 600));
      await tester.pump();

      expect(find.byKey(const Key('session-popover')), findsNothing);
    });

    testWidgets('a click inside it does not close it', (tester) async {
      await pumpButton(tester);
      await tester.tap(find.byKey(const Key('session-button')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('session-popover')));
      await tester.pump();

      expect(find.byKey(const Key('session-popover')), findsOneWidget);
    });

    testWidgets('is titled with the active environment, 420px wide, on surfaceContainerLow', (tester) async {
      await pumpButton(tester);
      await tester.tap(find.byKey(const Key('session-button')));
      await tester.pump();

      expect(find.text('Session · Dev'), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('session-popover'))).width, 420);
      final box = tester.widget<Container>(find.byKey(const Key('session-popover')));
      expect((box.decoration! as BoxDecoration).color, AppColors.surfaceContainerLow);
    });

    testWidgets('says No environment when none is active', (tester) async {
      await pumpButton(tester, activeId: null);
      await tester.tap(find.byKey(const Key('session-button')));
      await tester.pump();

      expect(find.text('Session · No environment'), findsOneWidget);
    });
  });
}
