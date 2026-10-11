import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/ui/request_builder/request_draft_provider.dart';
import 'package:api_flow_studio/ui/request_builder/tabs/body_tab.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpBodyTab(WidgetTester tester, RequestBody body) async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(requestDraftProvider.notifier).setBody(body);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: BodyTab())),
      ),
    );
  }

  String rawBody() => (container.read(requestDraftProvider).body as RequestBodyJson).raw;

  testWidgets('the JSON kind shows a Format JSON button and no warning for valid JSON', (tester) async {
    await pumpBodyTab(tester, const RequestBody.json('{"a":1}'));

    expect(find.byKey(const Key('format-json-button')), findsOneWidget);
    expect(find.byKey(const Key('invalid-json-warning')), findsNothing);
  });

  testWidgets('Format JSON reformats the body and the editor shows it', (tester) async {
    await pumpBodyTab(tester, const RequestBody.json('{"a":1}'));

    await tester.tap(find.byKey(const Key('format-json-button')));
    await tester.pump();

    expect(rawBody(), '{\n  "a": 1\n}');
    expect(tester.widget<TextField>(find.byKey(const Key('json-body-field'))).controller!.text, '{\n  "a": 1\n}');
  });

  testWidgets('Format JSON leaves an invalid body untouched', (tester) async {
    await pumpBodyTab(tester, const RequestBody.json('{"a":'));

    await tester.tap(find.byKey(const Key('format-json-button')));
    await tester.pump();

    expect(rawBody(), '{"a":');
  });

  testWidgets('Invalid JSON appears for a broken body in the warning color and goes away when fixed',
      (tester) async {
    await pumpBodyTab(tester, const RequestBody.json('{"a":'));

    final warning = find.byKey(const Key('invalid-json-warning'));
    expect(warning, findsOneWidget);
    expect(find.text('Invalid JSON'), findsOneWidget);
    expect(tester.widget<Text>(warning).style?.color, AppColors.warning);

    await tester.enterText(find.byKey(const Key('json-body-field')), '{"a":1}');
    await tester.pump();

    expect(warning, findsNothing);
  });

  testWidgets('a {{token}} inside a string does not trigger the warning', (tester) async {
    await pumpBodyTab(tester, const RequestBody.json('{"t":"{{token}}"}'));

    expect(find.byKey(const Key('invalid-json-warning')), findsNothing);
  });

  testWidgets('other body kinds show neither control', (tester) async {
    await pumpBodyTab(tester, const RequestBody.none());
    expect(find.byKey(const Key('format-json-button')), findsNothing);
    expect(find.byKey(const Key('invalid-json-warning')), findsNothing);

    await pumpBodyTab(tester, const RequestBody.formUrlEncoded([]));
    await tester.pump();
    expect(find.byKey(const Key('format-json-button')), findsNothing);
    expect(find.byKey(const Key('invalid-json-warning')), findsNothing);
  });

  group('Form Data', () {
    testWidgets('the Form Data segment switches to an empty multipart body with its table', (tester) async {
      await pumpBodyTab(tester, const RequestBody.none());

      await tester.tap(find.text('Form Data'));
      await tester.pumpAndSettle();

      expect(container.read(requestDraftProvider).body, const RequestBody.multipart([]));
      expect(find.byKey(const Key('add-multipart-field')), findsOneWidget);
    });

    testWidgets('a multipart body already in the draft opens on the Form Data table with its fields', (tester) async {
      await pumpBodyTab(tester, const RequestBody.multipart([MultipartField(name: 'title', value: 'Hello')]));

      expect(find.byKey(const Key('multipart-name-0')), findsOneWidget);
      expect(tester.widget<SegmentedButton<BodyKind>>(find.byKey(const Key('body-kind-selector'))).selected, {BodyKind.multipart});
    });

    testWidgets('editing the table writes the body back to the draft', (tester) async {
      await pumpBodyTab(tester, const RequestBody.multipart([]));

      await tester.tap(find.byKey(const Key('add-multipart-field')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('multipart-name-0')), 'title');
      await tester.enterText(find.byKey(const Key('multipart-value-0')), 'Hello');
      await tester.pump();

      expect(container.read(requestDraftProvider).body, const RequestBody.multipart([MultipartField(name: 'title', value: 'Hello')]));
    });

    testWidgets('switching to another kind resets the body, as it does between the other kinds', (tester) async {
      await pumpBodyTab(tester, const RequestBody.multipart([MultipartField(name: 'title', value: 'Hello')]));

      await tester.tap(find.text('JSON'));
      await tester.pumpAndSettle();

      expect(container.read(requestDraftProvider).body, const RequestBody.json(''));
    });
  });
}
