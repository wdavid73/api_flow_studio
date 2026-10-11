import 'package:api_flow_studio/engine/import/import_result.dart';
import 'package:api_flow_studio/ui/import/import_summary_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(WidgetTester tester, int warnings) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showImportSummaryDialog(
            context,
            ImportSummary(
              source: 'OpenAPI 3.0 spec',
              folders: 1,
              requests: 1,
              environments: 0,
              valuesToFill: 0,
              warnings: [for (var i = 0; i < warnings; i++) ImportWarning(where: 'GET /p$i', message: 'thing $i')],
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a few warnings are all listed, and the count is exact', (tester) async {
    await open(tester, 3);

    expect(find.text('3 things were left out or changed:'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-warning-2')), findsOneWidget);
    expect(find.byKey(const Key('import-warnings-hidden')), findsNothing);
  });

  testWidgets('thousands of warnings list the first ones and say how many are not shown', (tester) async {
    await open(tester, 5000);

    expect(find.text('5000 things were left out or changed:'), findsOneWidget);
    expect(find.byKey(const ValueKey('import-warning-0')), findsOneWidget);
    // The list builds only what is on screen: go to its end.
    await tester.scrollUntilVisible(find.byKey(const Key('import-warnings-hidden')), 500, scrollable: find.byType(Scrollable).last);

    expect(find.byKey(ValueKey('import-warning-${maxListedImportWarnings - 1}')), findsOneWidget);
    expect(find.byKey(ValueKey('import-warning-$maxListedImportWarnings')), findsNothing);
    expect(find.text('…and ${5000 - maxListedImportWarnings} more not shown'), findsOneWidget);
  });
}
