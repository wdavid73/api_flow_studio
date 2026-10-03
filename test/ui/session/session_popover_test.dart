import 'dart:convert';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/session/session.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/session/session_button.dart';
import 'package:api_flow_studio/ui/session/session_provider.dart';
import 'package:api_flow_studio/ui/shell/header_ghost_button.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String jwt(Map<String, Object?> claims) {
  String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.${part(claims)}.sig';
}

void main() {
  late ProviderContainer container;
  final clock = DateTime.utc(2026, 10, 2, 12);

  int secs(Duration fromNow) => clock.add(fromNow).millisecondsSinceEpoch ~/ 1000;

  Future<void> openPopover(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = JsonStore.inMemory();
    await store.writeEnvironments(const [Environment(id: 'a', name: 'Dev'), Environment(id: 'b', name: 'QA')]);
    await store.writeActiveEnvironmentId('a');
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
          home: const Scaffold(body: Align(alignment: Alignment.topRight, child: SessionButton())),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('session-button')));
    await tester.pump();
  }

  Session session([String key = 'a']) => container.read(sessionsProvider)[key] ?? const Session();

  TextField field(WidgetTester tester, String key) => tester.widget<TextField>(find.byKey(Key(key)));

  String metaText(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('session-meta'))).data ?? '';

  testWidgets('typing an access token updates the active environment session', (tester) async {
    await openPopover(tester);

    await tester.enterText(find.byKey(const Key('session-access-field')), 'my-access');
    await tester.pump();

    expect(session().accessToken, 'my-access');
    expect(session('b').hasToken, isFalse);
  });

  testWidgets('typing a refresh token updates the session and keeps the access token', (tester) async {
    await openPopover(tester);
    container.read(sessionsProvider.notifier).update('a', const Session(accessToken: 'keep'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('session-refresh-field')), 'my-refresh');
    await tester.pump();

    expect(session().refreshToken, 'my-refresh');
    expect(session().accessToken, 'keep');
  });

  testWidgets('both token fields are obscured until Show is checked', (tester) async {
    await openPopover(tester);

    expect(field(tester, 'session-access-field').obscureText, isTrue);
    expect(field(tester, 'session-refresh-field').obscureText, isTrue);

    await tester.tap(find.byKey(const Key('session-show-checkbox')));
    await tester.pump();

    expect(field(tester, 'session-access-field').obscureText, isFalse);
    expect(field(tester, 'session-refresh-field').obscureText, isFalse);

    await tester.tap(find.byKey(const Key('session-show-checkbox')));
    await tester.pump();

    expect(field(tester, 'session-access-field').obscureText, isTrue);
  });

  testWidgets('Send Authorization and Capture tokens are on by default and drive the session', (tester) async {
    await openPopover(tester);
    Checkbox box(String key) => tester.widget<Checkbox>(find.byKey(Key(key)));

    expect(find.text('Send Authorization'), findsOneWidget);
    expect(find.text('Capture tokens from 2xx'), findsOneWidget);
    expect(box('session-attach-checkbox').value, isTrue);
    expect(box('session-capture-checkbox').value, isTrue);

    await tester.tap(find.byKey(const Key('session-attach-checkbox')));
    await tester.pump();
    expect(session().attachAuth, isFalse);
    expect(session().captureTokens, isTrue);

    await tester.tap(find.byKey(const Key('session-capture-checkbox')));
    await tester.pump();
    expect(session().captureTokens, isFalse);
    expect(box('session-capture-checkbox').value, isFalse);
  });

  group('metadata line', () {
    testWidgets('shows sub and time left for a JWT', (tester) async {
      await openPopover(tester);
      container.read(sessionsProvider.notifier).update(
            'a',
            Session(accessToken: jwt({'sub': 'user-1', 'exp': secs(const Duration(minutes: 12))})),
          );
      await tester.pump();

      expect(metaText(tester), 'sub user-1 · Expires in 12 min');
    });

    testWidgets('shows only the expiry when there is no sub, and Token expired when past', (tester) async {
      await openPopover(tester);
      container.read(sessionsProvider.notifier).update(
            'a',
            Session(accessToken: jwt({'exp': secs(const Duration(minutes: -5))})),
          );
      await tester.pump();

      expect(metaText(tester), 'Token expired');
    });

    testWidgets('says a non-JWT is still sent as a Bearer', (tester) async {
      await openPopover(tester);
      container.read(sessionsProvider.notifier).update('a', const Session(accessToken: 'opaque'));
      await tester.pump();

      expect(metaText(tester), "Doesn't look like a JWT. It is still sent as a Bearer.");
    });

    testWidgets('is empty without a token', (tester) async {
      await openPopover(tester);

      expect(find.byKey(const Key('session-meta')), findsNothing);
    });

    testWidgets('never repeats the token', (tester) async {
      await openPopover(tester);
      container.read(sessionsProvider.notifier).update('a', const Session(accessToken: 'super-secret-opaque'));
      await tester.pump();

      expect(metaText(tester), isNot(contains('super-secret-opaque')));
    });
  });

  testWidgets('Clear tokens empties both tokens and keeps the checkboxes', (tester) async {
    await openPopover(tester);
    container
        .read(sessionsProvider.notifier)
        .update('a', const Session(accessToken: 'a', refreshToken: 'r', attachAuth: false));
    await tester.pump();

    expect(tester.widget(find.byKey(const Key('session-clear-button'))), isA<HeaderGhostButton>());
    await tester.tap(find.byKey(const Key('session-clear-button')));
    await tester.pump();

    expect(session().accessToken, isEmpty);
    expect(session().refreshToken, isEmpty);
    expect(session().attachAuth, isFalse);
    expect(field(tester, 'session-access-field').controller!.text, isEmpty);
  });

  testWidgets('switching the active environment shows that environment\'s tokens', (tester) async {
    await openPopover(tester);
    container.read(sessionsProvider.notifier)
      ..update('a', const Session(accessToken: 'token-of-dev'))
      ..update('b', const Session(accessToken: 'token-of-qa'));
    await tester.pump();
    expect(field(tester, 'session-access-field').controller!.text, 'token-of-dev');

    await container.read(environmentsProvider.notifier).setActive('b');
    await tester.pump();
    await tester.pump();

    expect(field(tester, 'session-access-field').controller!.text, 'token-of-qa');
    expect(find.text('Session · QA'), findsOneWidget);
  });

  testWidgets('tokens captured from a response appear in the open popover', (tester) async {
    await openPopover(tester);

    container.read(sessionsProvider.notifier).update('a', const Session(accessToken: 'just-captured'));
    await tester.pump();

    expect(field(tester, 'session-access-field').controller!.text, 'just-captured');
  });
}
