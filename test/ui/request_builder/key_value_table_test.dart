import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/ui/request_builder/key_value_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('add row appends an empty enabled entry', (tester) async {
    List<KeyValueEntry>? result;
    await tester.pumpWidget(wrap(KeyValueTable(entries: const [], onChanged: (v) => result = v)));

    await tester.tap(find.text('Add row'));
    await tester.pump();

    expect(result, [const KeyValueEntry(key: '', value: '')]);
  });

  testWidgets('editing the key field updates just that row', (tester) async {
    List<KeyValueEntry>? result;
    const entries = [KeyValueEntry(key: '', value: 'x')];
    await tester.pumpWidget(wrap(KeyValueTable(entries: entries, onChanged: (v) => result = v)));

    await tester.enterText(find.byKey(const Key('kv-key-field')), 'Authorization');

    expect(result, [const KeyValueEntry(key: 'Authorization', value: 'x')]);
  });

  testWidgets('toggling the checkbox flips enabled', (tester) async {
    List<KeyValueEntry>? result;
    const entries = [KeyValueEntry(key: 'a', value: 'b')];
    await tester.pumpWidget(wrap(KeyValueTable(entries: entries, onChanged: (v) => result = v)));

    await tester.tap(find.byKey(const Key('kv-enabled-checkbox')));

    expect(result, [const KeyValueEntry(key: 'a', value: 'b', enabled: false)]);
  });

  testWidgets('delete removes that row', (tester) async {
    List<KeyValueEntry>? result;
    const entries = [
      KeyValueEntry(key: 'a', value: '1'),
      KeyValueEntry(key: 'b', value: '2'),
    ];
    await tester.pumpWidget(wrap(KeyValueTable(entries: entries, onChanged: (v) => result = v)));

    await tester.tap(find.byKey(const Key('kv-delete-button')).first);

    expect(result, [const KeyValueEntry(key: 'b', value: '2')]);
  });
}
