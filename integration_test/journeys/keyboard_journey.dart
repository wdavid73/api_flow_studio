import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/journey_harness.dart';

/// Journey 9: the keyboard shortcuts, with the whole app around them.
void defineKeyboardJourney(JourneyHarness Function() harness) {
  group('Keyboard journey', () {
    Future<void> ctrlEnter(WidgetTester tester, AppDriver app) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await app.settle();
    }

    bool searchHasFocus(WidgetTester tester) => tester
        .widget<EditableText>(find.descendant(of: find.byKey(const Key('sidebar-search-field')), matching: find.byType(EditableText)))
        .focusNode
        .hasPrimaryFocus;

    journeyTest('Ctrl+Enter sends the open request once', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');

      await ctrlEnter(tester, app);

      expect(app.backend.calls, hasLength(1));
      expect(find.descendant(of: app.responsePane, matching: find.text('200')), findsOneWidget);
    });

    journeyTest('Ctrl+Enter works while typing in the URL field', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');
      await tester.tap(find.byKey(const Key('request-url-field')));
      await app.settle();

      await ctrlEnter(tester, app);

      expect(app.backend.calls, hasLength(1));
    });

    journeyTest('slash focuses the sidebar search when nothing is being typed', (tester) async {
      final app = await harness().launchApp(tester);
      expect(searchHasFocus(tester), isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await app.settle();

      expect(searchHasFocus(tester), isTrue);
    });

    journeyTest('slash pressed while typing in the URL field does not jump to the search', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');
      await tester.tap(find.byKey(const Key('request-url-field')));
      await app.settle();

      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await app.settle();

      expect(searchHasFocus(tester), isFalse);
    });

    journeyTest('Esc closes the session popover and the hosts dialog', (tester) async {
      final app = await harness().launchApp(tester);

      await app.tapKey(const Key('session-button'));
      expect(find.byKey(const Key('session-popover')), findsOneWidget);
      await app.pressEscape();
      expect(find.byKey(const Key('session-popover')), findsNothing);

      await app.openHostsDialog();
      expect(find.byKey(const Key('hosts-close-button')), findsOneWidget);
      await app.pressEscape();
      expect(find.byKey(const Key('hosts-close-button')), findsNothing);
    });
  });
}
