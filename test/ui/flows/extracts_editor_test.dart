import 'package:api_flow_studio/ui/flows/extracts_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Keeps the extract map in state like the panel does, so edits flow back in.
  Future<ValueNotifier<Map<String, String>>> pumpEditor(
    WidgetTester tester,
    Map<String, String> extract, {
    Set<String>? knownPaths,
  }) async {
    final notifier = ValueNotifier(extract);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<Map<String, String>>(
          valueListenable: notifier,
          builder: (context, current, _) => ExtractsEditor(
            stepIndex: 0,
            extract: current,
            knownPaths: knownPaths,
            onChanged: (next) => notifier.value = next,
          ),
        ),
      ),
    ));
    return notifier;
  }

  String fieldText(WidgetTester tester, String key) => tester
      .widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText)))
      .controller
      .text;

  testWidgets('adding an extract row and filling it in reports the updated map', (tester) async {
    final extract = await pumpEditor(tester, const {});

    await tester.tap(find.byKey(const Key('add-extract-0')));
    await tester.pump();
    expect(extract.value, {'variable': ''});

    await tester.enterText(find.byKey(const Key('extract-name-0-0')), 'user_id');
    await tester.pump();
    expect(extract.value, {'user_id': ''});

    await tester.enterText(find.byKey(const Key('extract-path-0-0')), 'response.body.id');
    await tester.pump();
    expect(extract.value, {'user_id': 'response.body.id'});
  });

  testWidgets('a second row gets a name that is not taken', (tester) async {
    final extract = await pumpEditor(tester, const {'variable': 'response.body.a'});

    await tester.tap(find.byKey(const Key('add-extract-0')));
    await tester.pump();

    expect(extract.value.keys, ['variable', 'variable_1']);
  });

  testWidgets('removing an extract row drops it from the map', (tester) async {
    final extract = await pumpEditor(tester, const {'user_id': 'response.body.id'});

    await tester.tap(find.byKey(const Key('remove-extract-0-0')));
    await tester.pump();

    expect(extract.value, isEmpty);
  });

  testWidgets('marks an extract whose path is not in the last response', (tester) async {
    await pumpEditor(
      tester,
      const {'otp': 'response.body.otp', 'id': 'response.body.id'},
      knownPaths: const {'response.body.id'},
    );

    expect(find.text('not in the last response'), findsOneWidget);
  });

  testWidgets('without a known response nothing is marked', (tester) async {
    await pumpEditor(tester, const {'otp': 'response.body.otp'});

    expect(find.text('not in the last response'), findsNothing);
  });

  testWidgets('an extract changed from outside shows its new path', (tester) async {
    final extract = await pumpEditor(tester, const {'user_id': 'response.body.id'});

    extract.value = const {'user_id': 'response.body.user.id'};
    await tester.pump();

    expect(fieldText(tester, 'extract-path-0-0'), 'response.body.user.id');
  });

  testWidgets('typing keeps the field focused', (tester) async {
    await pumpEditor(tester, const {'user_id': ''});

    await tester.tap(find.byKey(const Key('extract-path-0-0')));
    await tester.enterText(find.byKey(const Key('extract-path-0-0')), 'response.b');
    await tester.pump();

    final editable = tester.widget<EditableText>(
      find.descendant(of: find.byKey(const Key('extract-path-0-0')), matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.hasFocus, isTrue);
    expect(fieldText(tester, 'extract-path-0-0'), 'response.b');
  });
}
