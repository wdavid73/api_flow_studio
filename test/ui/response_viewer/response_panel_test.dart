import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/ui/request_builder/send_provider.dart';
import 'package:api_flow_studio/ui/response_viewer/response_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(SendState state) =>
      MaterialApp(home: Scaffold(body: ResponsePanel(sendState: state)));

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

  testWidgets('the copy button copies the raw body to the clipboard', (tester) async {
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

    await tester.pumpWidget(wrap(const SendState(
      response: ExecutedResponse(status: 200, body: '{"a":1}'),
    )));

    await tester.tap(find.byKey(const Key('copy-body-button')));
    await tester.pump();

    final copyCall = calls.where((c) => c.method == 'Clipboard.setData').single;
    expect(copyCall.arguments['text'], '{"a":1}');
  });

  testWidgets('a transport error shows inline instead of the tabbed viewer', (tester) async {
    await tester.pumpWidget(wrap(const SendState(
      response: ExecutedResponse(error: 'Connection refused'),
    )));

    expect(find.byKey(const Key('response-error')), findsOneWidget);
    expect(find.text('Body'), findsNothing);
  });
}
