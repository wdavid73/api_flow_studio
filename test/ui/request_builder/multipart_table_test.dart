import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/ui/request_builder/file_picker_service.dart';
import 'package:api_flow_studio/ui/request_builder/multipart_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hands back the paths it was given, one per call (null = the dialog was cancelled).
class FakeFilePicker implements FilePickerService {
  FakeFilePicker(this.answers);

  final List<String?> answers;
  int calls = 0;

  @override
  Future<String?> pickFile() async => answers[calls++];
}

void main() {
  late ValueNotifier<List<MultipartField>> fields;

  Future<FakeFilePicker> pump(
    WidgetTester tester,
    List<MultipartField> initial, {
    List<String?> picks = const [],
  }) async {
    final picker = FakeFilePicker(picks);
    fields = ValueNotifier(initial);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [filePickerServiceProvider.overrideWithValue(picker)],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<List<MultipartField>>(
              valueListenable: fields,
              builder: (context, current, _) => SingleChildScrollView(
                child: MultipartTable(fields: current, onChanged: (next) => fields.value = next),
              ),
            ),
          ),
        ),
      ),
    );
    return picker;
  }

  /// What the text field with [key] is showing (a hint is not text).
  String textOf(WidgetTester tester, String key) => tester
      .widget<EditableText>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(EditableText)))
      .controller
      .text;

  Future<void> chooseKind(WidgetTester tester, int row, String label) async {
    await tester.tap(find.byKey(Key('multipart-kind-$row')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  const file = MultipartField(name: 'avatar', kind: MultipartFieldKind.file, value: '/tmp/a.png');

  testWidgets('with no fields only the add button shows', (tester) async {
    await pump(tester, const []);

    expect(find.byKey(const Key('add-multipart-field')), findsOneWidget);
    expect(find.byKey(const Key('multipart-name-0')), findsNothing);
  });

  testWidgets('Add field appends a blank text field', (tester) async {
    await pump(tester, const []);

    await tester.tap(find.byKey(const Key('add-multipart-field')));
    await tester.pumpAndSettle();

    expect(fields.value, [const MultipartField(name: '')]);
    expect(find.byKey(const Key('multipart-value-0')), findsOneWidget);
    expect(find.byKey(const Key('multipart-path-0')), findsNothing);
  });

  testWidgets('typing a name and a text value updates the field', (tester) async {
    await pump(tester, const [MultipartField(name: '')]);

    await tester.enterText(find.byKey(const Key('multipart-name-0')), 'title');
    await tester.enterText(find.byKey(const Key('multipart-value-0')), 'Hello');
    await tester.pump();

    expect(fields.value, [const MultipartField(name: 'title', value: 'Hello')]);
  });

  testWidgets('the checkbox enables and disables a field', (tester) async {
    await pump(tester, const [MultipartField(name: 'a', value: 'b')]);

    await tester.tap(find.byKey(const Key('multipart-enabled-0')));
    await tester.pump();

    expect(fields.value.single.enabled, isFalse);
  });

  group('file fields', () {
    testWidgets('show a path, a Choose button and a content type instead of a text value', (tester) async {
      await pump(tester, const [file]);

      expect(find.byKey(const Key('multipart-path-0')), findsOneWidget);
      expect(find.byKey(const Key('multipart-choose-0')), findsOneWidget);
      expect(find.byKey(const Key('multipart-type-0')), findsOneWidget);
      expect(find.byKey(const Key('multipart-value-0')), findsNothing);
      expect(textOf(tester, 'multipart-path-0'), '/tmp/a.png');
    });

    testWidgets('the path can be typed, which allows {{variables}}', (tester) async {
      await pump(tester, const [MultipartField(name: 'f', kind: MultipartFieldKind.file)]);

      await tester.enterText(find.byKey(const Key('multipart-path-0')), '{{fixtures}}/a.png');
      await tester.pump();

      expect(fields.value.single.value, '{{fixtures}}/a.png');
    });

    testWidgets('Choose opens the picker and fills the path, which then shows in the field', (tester) async {
      final picker = await pump(tester, const [MultipartField(name: 'f', kind: MultipartFieldKind.file)], picks: ['/home/ana/photo.jpg']);

      await tester.tap(find.byKey(const Key('multipart-choose-0')));
      await tester.pumpAndSettle();

      expect(picker.calls, 1);
      expect(fields.value.single.value, '/home/ana/photo.jpg');
      expect(textOf(tester, 'multipart-path-0'), '/home/ana/photo.jpg');
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      await pump(tester, const [file], picks: [null]);

      await tester.tap(find.byKey(const Key('multipart-choose-0')));
      await tester.pumpAndSettle();

      expect(fields.value, [file]);
      expect(textOf(tester, 'multipart-path-0'), '/tmp/a.png');
    });

    testWidgets('a content type typed is kept and clearing it goes back to none', (tester) async {
      await pump(tester, const [file]);

      await tester.enterText(find.byKey(const Key('multipart-type-0')), 'image/png');
      await tester.pump();
      expect(fields.value.single.contentType, 'image/png');

      await tester.enterText(find.byKey(const Key('multipart-type-0')), '');
      await tester.pump();
      expect(fields.value.single.contentType, isNull);
    });

    testWidgets('an enabled file field with no path warns "No file chosen"', (tester) async {
      await pump(tester, const [MultipartField(name: 'f', kind: MultipartFieldKind.file)]);

      expect(find.byKey(const Key('multipart-no-file-0')), findsOneWidget);
      expect(find.text('No file chosen'), findsOneWidget);
    });

    testWidgets('no warning once there is a path, or when the field is disabled', (tester) async {
      await pump(tester, const [
        file,
        MultipartField(name: 'off', kind: MultipartFieldKind.file, enabled: false),
      ]);

      expect(find.byKey(const Key('multipart-no-file-0')), findsNothing);
      expect(find.byKey(const Key('multipart-no-file-1')), findsNothing);
    });
  });

  group('changing the kind', () {
    testWidgets('Text to File keeps the name and starts with no file', (tester) async {
      await pump(tester, const [MultipartField(name: 'doc', value: 'some text')]);

      await chooseKind(tester, 0, 'File');

      expect(fields.value.single, const MultipartField(name: 'doc', kind: MultipartFieldKind.file));
      expect(find.byKey(const Key('multipart-path-0')), findsOneWidget);
      expect(textOf(tester, 'multipart-name-0'), 'doc');
    });

    testWidgets('File to Text keeps the name and drops the path and content type', (tester) async {
      await pump(tester, const [MultipartField(name: 'avatar', kind: MultipartFieldKind.file, value: '/tmp/a.png', contentType: 'image/png')]);

      await chooseKind(tester, 0, 'Text');

      expect(fields.value.single, const MultipartField(name: 'avatar'));
      expect(find.byKey(const Key('multipart-value-0')), findsOneWidget);
      expect(textOf(tester, 'multipart-value-0'), '');
    });
  });

  group('rows keep their own text', () {
    testWidgets('removing a row leaves the next one showing its own values', (tester) async {
      await pump(tester, const [
        MultipartField(name: 'first', value: 'one'),
        MultipartField(name: 'second', value: 'two'),
      ]);

      await tester.tap(find.byKey(const Key('multipart-remove-0')));
      await tester.pumpAndSettle();

      expect(fields.value, [const MultipartField(name: 'second', value: 'two')]);
      expect(textOf(tester, 'multipart-name-0'), 'second');
      expect(textOf(tester, 'multipart-value-0'), 'two');
      expect(find.byKey(const Key('multipart-name-1')), findsNothing);
    });

    testWidgets('a different body in the same place shows its own fields', (tester) async {
      await pump(tester, const [MultipartField(name: 'a', value: '1')]);
      expect(textOf(tester, 'multipart-name-0'), 'a');

      fields.value = const [MultipartField(name: 'b', kind: MultipartFieldKind.file, value: '/tmp/b.png')];
      await tester.pumpAndSettle();

      expect(textOf(tester, 'multipart-name-0'), 'b');
      expect(textOf(tester, 'multipart-path-0'), '/tmp/b.png');
    });

    testWidgets('typing does not rebuild the field (focus and cursor survive)', (tester) async {
      await pump(tester, const [MultipartField(name: 'a')]);
      final before = tester.state(find.byKey(const Key('multipart-name-0')));

      await tester.enterText(find.byKey(const Key('multipart-name-0')), 'abc');
      await tester.pump();

      expect(tester.state(find.byKey(const Key('multipart-name-0'))), same(before));
    });
  });
}
