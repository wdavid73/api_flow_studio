import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/history/history_tab.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/request_builder/request_draft_provider.dart';
import 'package:api_flow_studio/ui/request_builder/send_provider.dart';
import 'package:api_flow_studio/ui/response_viewer/response_panel.dart';
import 'package:api_flow_studio/ui/shell/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(SendState state, {JsonStore? store}) => ProviderScope(
        overrides: [jsonStoreProvider.overrideWithValue(store ?? JsonStore.inMemory())],
        child: MaterialApp(home: Scaffold(body: ResponsePanel(sendState: state))),
      );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ResponsePanel)));

  List<MethodCall> captureClipboard(WidgetTester tester) {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    return calls;
  }

  testWidgets('shows the status code via the StatusBadge and the elapsed/size chips',
      (tester) async {
    await tester.pumpWidget(wrap(const SendState(
      response: ExecutedResponse(status: 404, elapsedMs: 12, sizeBytes: 9, body: 'not found'),
    )));

    expect(find.text('404'), findsOneWidget);
    expect(find.byKey(const Key('response-elapsed')), findsOneWidget);
    expect(find.textContaining('12'), findsWidgets);
    expect(find.byKey(const Key('response-size')), findsOneWidget);
  });

  testWidgets('Body tab pretty-prints and syntax-highlights a JSON body by default',
      (tester) async {
    await tester.pumpWidget(wrap(const SendState(
      response: ExecutedResponse(status: 200, body: '{"a":1}'),
    )));

    expect(find.textContaining('"a"'), findsOneWidget);
    expect(find.text('1', findRichText: true), findsWidgets);
  });

  testWidgets('Headers tab lists response headers', (tester) async {
    await tester.pumpWidget(wrap(const SendState(
      response: ExecutedResponse(
        status: 200,
        headers: {'content-type': 'application/json'},
      ),
    )));

    await tester.tap(find.text('Headers'));
    await tester.pumpAndSettle();

    expect(find.text('content-type'), findsOneWidget);
    expect(find.text('application/json'), findsOneWidget);
  });

  testWidgets('Cookies tab shows an empty state when there is no Set-Cookie header',
      (tester) async {
    await tester.pumpWidget(wrap(const SendState(response: ExecutedResponse(status: 200))));

    await tester.tap(find.text('Cookies'));
    await tester.pumpAndSettle();

    expect(find.text('No cookies'), findsOneWidget);
  });

  testWidgets('Cookies tab lists a Set-Cookie header', (tester) async {
    await tester.pumpWidget(wrap(const SendState(
      response: ExecutedResponse(
        status: 200,
        headers: {'set-cookie': 'session=abc, theme=dark'},
      ),
    )));

    await tester.tap(find.text('Cookies'));
    await tester.pumpAndSettle();

    expect(find.text('session=abc'), findsOneWidget);
    expect(find.text('theme=dark'), findsOneWidget);
  });

  testWidgets('Timeline tab shows the elapsed time', (tester) async {
    await tester.pumpWidget(wrap(const SendState(
      response: ExecutedResponse(status: 200, elapsedMs: 88),
    )));

    await tester.tap(find.text('Timeline'));
    await tester.pumpAndSettle();

    expect(find.textContaining('response received, 88ms'), findsOneWidget);
  });

  testWidgets('the status line reads status, elapsed and size separated by dots', (tester) async {
    await tester.pumpWidget(wrap(const SendState(
      response: ExecutedResponse(status: 200, elapsedMs: 124, sizeBytes: 512, body: '{}'),
    )));

    expect(find.text('200'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('response-elapsed'))).data, '124 ms');
    expect(tester.widget<Text>(find.byKey(const Key('response-size'))).data, '512 B');
    expect(find.text('·'), findsNWidgets(2));
  });

  testWidgets('with no response it says so and explains how to send', (tester) async {
    await tester.pumpWidget(wrap(const SendState()));

    expect(find.text('No response yet'), findsOneWidget);
    expect(find.text('Pick a request and send. Cmd/Ctrl + Enter also sends.'), findsOneWidget);
  });

  testWidgets('Copy puts the raw body on the clipboard and toasts', (tester) async {
    final calls = captureClipboard(tester);
    await tester.pumpWidget(wrap(const SendState(
      response: ExecutedResponse(status: 200, body: '{"a":1}'),
    )));

    await tester.tap(find.byKey(const Key('copy-body-button')));
    await tester.pump();

    final copyCall = calls.where((c) => c.method == 'Clipboard.setData').single;
    expect(copyCall.arguments['text'], '{"a":1}');
    expect(containerOf(tester).read(toastProvider), 'Response copied');
    await tester.pump(toastDuration);
  });

  testWidgets('Copy with no response copies nothing and says so', (tester) async {
    final calls = captureClipboard(tester);
    await tester.pumpWidget(wrap(const SendState()));

    await tester.tap(find.byKey(const Key('copy-body-button')));
    await tester.pump();

    expect(calls.where((c) => c.method == 'Clipboard.setData'), isEmpty);
    expect(containerOf(tester).read(toastProvider), 'Nothing to copy');
    await tester.pump(toastDuration);
  });

  testWidgets('curl copies the current request with the active environment resolved', (tester) async {
    final calls = captureClipboard(tester);
    final store = JsonStore.inMemory();
    await store.writeEnvironments([
      const Environment(
        id: 'dev',
        name: 'Dev',
        variables: {'base': EnvironmentVariable(value: 'https://dev.example.com')},
      ),
    ]);
    await store.writeActiveEnvironmentId('dev');

    await tester.pumpWidget(wrap(const SendState(), store: store));
    final container = containerOf(tester);
    await tester.runAsync(() => container.read(environmentsProvider.future));
    container.read(requestDraftProvider.notifier).setUrl('{{base}}/users');

    await tester.tap(find.byKey(const Key('copy-curl-button')));
    await tester.pump();

    final copyCall = calls.where((c) => c.method == 'Clipboard.setData').single;
    expect(copyCall.arguments['text'], "curl -X GET 'https://dev.example.com/users'");
    expect(container.read(toastProvider), 'curl copied');
    await tester.pump(toastDuration);
  });

  testWidgets('a transport error shows inline instead of the tabbed viewer', (tester) async {
    await tester.pumpWidget(wrap(const SendState(
      response: ExecutedResponse(error: 'Connection refused'),
    )));

    expect(find.byKey(const Key('response-error')), findsOneWidget);
    expect(find.text('Body'), findsNothing);
  });

  group('Response / History tabs', () {
    testWidgets('the panel has Response and History tabs, Response first', (tester) async {
      await tester.pumpWidget(wrap(const SendState()));

      expect(find.widgetWithText(Tab, 'Response'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'History'), findsOneWidget);
      expect(find.byType(HistoryTab), findsNothing);
    });

    testWidgets('History for an unsaved draft says to save it first', (tester) async {
      await tester.pumpWidget(wrap(const SendState()));

      await tester.tap(find.widgetWithText(Tab, 'History'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-unsaved-state')), findsOneWidget);
    });

    testWidgets('History for a saved endpoint with no entries shows the empty state', (tester) async {
      await tester.pumpWidget(wrap(const SendState()));
      containerOf(tester).read(requestDraftProvider.notifier).loadEndpoint(
            const Endpoint(id: 'e-1', groupId: 'g-1', name: 'Get', method: 'GET', url: 'https://x.test'),
          );

      await tester.tap(find.widgetWithText(Tab, 'History'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('empty-history-state')), findsOneWidget);
    });

    testWidgets('History lists the stored entries of the loaded endpoint', (tester) async {
      final store = JsonStore.inMemory();
      await store.appendHistoryEntry(
        'e-1',
        HistoryEntry(id: 'h1', endpointId: 'e-1', timestamp: DateTime(2026), status: 200, elapsedMs: 7),
      );
      await tester.pumpWidget(wrap(const SendState(), store: store));
      containerOf(tester).read(requestDraftProvider.notifier).loadEndpoint(
            const Endpoint(id: 'e-1', groupId: 'g-1', name: 'Get', method: 'GET', url: 'https://x.test'),
          );

      await tester.tap(find.widgetWithText(Tab, 'History'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-list')), findsOneWidget);
      expect(find.byKey(const ValueKey('history-row-h1')), findsOneWidget);
    });
  });
}
