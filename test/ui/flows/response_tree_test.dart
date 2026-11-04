import 'package:api_flow_studio/ui/flows/response_tree.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<String>> pumpTree(WidgetTester tester, {Object? body, int? status = 200}) async {
    final tapped = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ResponseTree(
            status: status,
            headers: const {'content-type': 'application/json'},
            body: body,
            onValueTap: (path, _) => tapped.add(path),
          ),
        ),
      ),
    ));
    return tapped;
  }

  testWidgets('every leaf is tappable with its full path', (tester) async {
    final tapped = await pumpTree(tester, body: {
      'user': {'id': 'u1'},
      'items': [
        {'sku': 'a'},
      ],
    });

    for (final path in [
      'response.status',
      'response.headers.content-type',
      'response.body.user.id',
      'response.body.items.0.sku',
    ]) {
      await tester.tap(find.byKey(Key('response-tree-value-$path')));
    }

    expect(tapped, [
      'response.status',
      'response.headers.content-type',
      'response.body.user.id',
      'response.body.items.0.sku',
    ]);
  });

  testWidgets('shows the values next to their keys', (tester) async {
    await pumpTree(tester, body: {'user': {'id': 'u1'}});

    expect(find.textContaining('"u1"'), findsOneWidget);
    expect(find.textContaining('200'), findsOneWidget);
  });

  testWidgets('a body that is not JSON is shown as text', (tester) async {
    await pumpTree(tester, body: '<html>oops</html>');

    expect(find.text('<html>oops</html>'), findsOneWidget);
    expect(find.byKey(const Key('response-tree-value-response.body')), findsNothing);
  });

  testWidgets('a very deep body renders, cut with … past the depth limit', (tester) async {
    // As wide as the side panel: the indentation must not run out of room.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Object? body = 'bottom';
    for (var i = 0; i < 10000; i++) {
      body = {'a': body};
    }

    await pumpTree(tester, body: body);

    expect(tester.takeException(), isNull);
    expect(find.text('…'), findsOneWidget);
  });

  testWidgets('a huge object lists its first entries and cuts the rest with …', (tester) async {
    await pumpTree(tester, body: {for (var i = 0; i < 5000; i++) 'k$i': i});

    expect(find.byKey(const Key('response-tree-value-response.body.k0')), findsOneWidget);
    expect(find.byKey(const Key('response-tree-value-response.body.k4999')), findsNothing);
    expect(find.text('…'), findsOneWidget);
  });
}
