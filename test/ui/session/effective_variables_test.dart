import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/session/session.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/request_builder/request_draft_provider.dart';
import 'package:api_flow_studio/ui/request_builder/send_provider.dart';
import 'package:api_flow_studio/ui/request_builder/url_field.dart';
import 'package:api_flow_studio/ui/response_viewer/response_panel.dart';
import 'package:api_flow_studio/ui/session/session_provider.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  Future<void> setUpContainer({String? activeId = 'a', Map<String, EnvironmentVariable> variables = const {}}) async {
    final store = JsonStore.inMemory();
    await store.writeEnvironments([Environment(id: 'a', name: 'Dev', variables: variables)]);
    await store.writeActiveEnvironmentId(activeId);
    container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    await container.read(environmentsProvider.future);
  }

  void setSession(Session session, {String key = 'a'}) => container.read(sessionsProvider.notifier).update(key, session);

  group('effectiveVariablesProvider', () {
    test('merges the active environment variables with the session ones', () async {
      await setUpContainer(variables: const {'base': EnvironmentVariable(value: 'https://dev')});
      setSession(const Session(accessToken: 'tok', refreshToken: 'ref'));

      expect(container.read(effectiveVariablesProvider), {
        'base': 'https://dev',
        'session_access_token': 'tok',
        'session_refresh_token': 'ref',
      });
    });

    test('an environment variable with the same name wins', () async {
      await setUpContainer(variables: const {'session_access_token': EnvironmentVariable(value: 'from-env')});
      setSession(const Session(accessToken: 'tok'));

      expect(container.read(effectiveVariablesProvider)['session_access_token'], 'from-env');
    });

    test('with no active environment only the "no environment" session counts', () async {
      await setUpContainer(activeId: null);
      setSession(const Session(accessToken: 'dev-token'), key: 'a');
      setSession(const Session(accessToken: 'loose-token'), key: noEnvironmentKey);

      expect(container.read(effectiveVariablesProvider), {'session_access_token': 'loose-token'});
    });

    test('is empty without variables or tokens, and follows a cleared session', () async {
      await setUpContainer();
      expect(container.read(effectiveVariablesProvider), isEmpty);

      setSession(const Session(accessToken: 'tok'));
      expect(container.read(effectiveVariablesProvider), isNotEmpty);

      setSession(const Session());
      expect(container.read(effectiveVariablesProvider), isEmpty);
    });
  });

  group('curl button', () {
    List<MethodCall> captureClipboard(WidgetTester tester) {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      return calls;
    }

    Future<String> copyCurl(WidgetTester tester, {Endpoint? draft}) async {
      final calls = captureClipboard(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const Scaffold(body: ResponsePanel(sendState: SendState())),
          ),
        ),
      );
      if (draft != null) container.read(requestDraftProvider.notifier).loadEndpoint(draft);
      await tester.tap(find.byKey(const Key('copy-curl-button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      return calls.where((c) => c.method == 'Clipboard.setData').single.arguments['text'] as String;
    }

    const draft = Endpoint(id: 'e1', groupId: 'g', name: 'Me', method: 'GET', url: 'https://x.test/me');

    testWidgets('includes the Bearer header of the session', (tester) async {
      await setUpContainer();
      setSession(const Session(accessToken: 'tok'));

      final curl = await copyCurl(tester, draft: draft);

      expect(curl, contains("-H 'Authorization: Bearer tok'"));
    });

    testWidgets('has no Authorization without a token or with Send Authorization off', (tester) async {
      await setUpContainer();
      expect(await copyCurl(tester, draft: draft), isNot(contains('Authorization')));

      setSession(const Session(accessToken: 'tok', attachAuth: false));
      expect(await copyCurl(tester, draft: draft), isNot(contains('Authorization')));
    });

    testWidgets('does not override an Authorization the request sets itself', (tester) async {
      await setUpContainer();
      setSession(const Session(accessToken: 'tok'));

      final curl = await copyCurl(
        tester,
        draft: draft.copyWith(headers: const [KeyValueEntry(key: 'Authorization', value: 'Basic mine')]),
      );

      expect(curl, contains("-H 'Authorization: Basic mine'"));
      expect(curl, isNot(contains('Bearer tok')));
    });

    testWidgets('resolves {{session_access_token}} in the URL', (tester) async {
      await setUpContainer();
      setSession(const Session(accessToken: 'tok'));

      final curl = await copyCurl(tester, draft: draft.copyWith(url: 'https://x.test/me?t={{session_access_token}}'));

      expect(curl, contains("'https://x.test/me?t=tok'"));
    });
  });

  group('URL field highlighting', () {
    Future<List<InlineSpan>> spansFor(WidgetTester tester, String url) async {
      container.read(requestDraftProvider.notifier).setUrl(url);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: UrlField())),
        ),
      );
      await tester.pump();
      final controller = tester.widget<TextField>(find.byKey(const Key('request-url-field'))).controller!;
      final context = tester.element(find.byKey(const Key('request-url-field')));
      return controller.buildTextSpan(context: context, withComposing: false).children!;
    }

    Color? colorOfVariable(List<InlineSpan> spans, String token) {
      for (final span in spans) {
        if (span is TextSpan && span.text == token) return span.style?.color;
      }
      return null;
    }

    testWidgets('a session variable counts as resolved once there is a token', (tester) async {
      await setUpContainer();
      setSession(const Session(accessToken: 'tok'));

      final spans = await spansFor(tester, '{{session_access_token}}/x');

      expect(colorOfVariable(spans, '{{session_access_token}}'), AppColors.variableResolvedText);
    });

    testWidgets('and as unresolved without one', (tester) async {
      await setUpContainer();

      final spans = await spansFor(tester, '{{session_access_token}}/x');

      expect(colorOfVariable(spans, '{{session_access_token}}'), AppColors.variableUnresolvedText);
    });
  });
}
