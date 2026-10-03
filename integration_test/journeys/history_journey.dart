import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/journey_harness.dart';

/// Journey 3: what was sent is remembered, listed, and can be reopened.
void defineHistoryJourney(JourneyHarness Function() harness) {
  group('History journey', () {
    journeyTest('a sent saved request appears in the response History tab', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');
      await app.send();

      await app.openResponseHistoryTab();

      expect(find.byKey(const Key('history-list')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('history-list')), matching: find.text('200')), findsOneWidget);
    });

    journeyTest('it also appears in the History screen with method, name, url and status', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');
      await app.send();

      await app.goTo('History');

      final screen = find.byKey(const Key('history-screen'));
      expect(find.descendant(of: screen, matching: find.text('List items')), findsOneWidget);
      expect(find.descendant(of: screen, matching: find.text('GET')), findsOneWidget);
      expect(find.descendant(of: screen, matching: find.text('{{base_url}}/items')), findsOneWidget);
      expect(find.descendant(of: screen, matching: find.text('200')), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
    });

    journeyTest('tapping a history row reopens that request in the Workspace', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');
      await app.send();
      await app.openRequest('e-me'); // something else is loaded now
      await app.goTo('History');

      await tester.tap(find.text('List items'));
      await app.settle();

      expect(find.byKey(const Key('workspace-request-pane')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('request-header-title'))).data, 'List items');
      expect(tester.widget<TextField>(find.byKey(const Key('request-url-field'))).controller!.text, '{{base_url}}/items');
    });

    journeyTest('a failed send is listed as Error', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-boom');
      await app.send();

      await app.goTo('History');

      expect(find.descendant(of: find.byKey(const Key('history-screen')), matching: find.text('Error')), findsOneWidget);
    });

    journeyTest('the newest send is listed first and the search narrows the list', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');
      await app.send();
      await app.openRequest('e-flaky');
      await app.send();

      await app.goTo('History');

      expect(
        tester.getTopLeft(find.text('Server error')).dy,
        lessThan(tester.getTopLeft(find.text('List items')).dy),
      );

      await tester.enterText(find.byKey(const Key('history-search-field')), 'items');
      await app.settle();

      expect(find.text('List items'), findsOneWidget);
      expect(find.text('Server error'), findsNothing);
    });

    journeyTest('every send of the same request is kept', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');
      await app.send();
      await app.send();
      await app.send();

      await app.goTo('History');

      expect(find.text('List items'), findsNWidgets(3));
    });

    journeyTest('Clear history asks first and Cancel keeps everything', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');
      await app.send();
      await app.goTo('History');

      await app.tapKey(const Key('clear-history-button'));
      expect(find.textContaining('Clear the history of "Default"'), findsOneWidget);
      await app.tapKey(const Key('clear-history-cancel-button'));

      expect(find.byKey(const Key('history-screen-empty')), findsNothing);
      expect(find.text('List items'), findsOneWidget);
    });

    journeyTest('clearing the history empties the screen and the request History tab, and sends are recorded again', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');
      await app.send();
      await app.send();
      await app.goTo('History');

      await app.tapKey(const Key('clear-history-button'));
      await app.tapKey(const Key('clear-history-confirm-button'));

      expect(find.byKey(const Key('history-screen-empty')), findsOneWidget);
      expect(find.text('History cleared'), findsOneWidget);
      expect(await app.store.readAllHistory(), isEmpty);

      await app.goTo('Workspace');
      await app.openResponseHistoryTab();
      expect(find.byKey(const Key('empty-history-state')), findsOneWidget);

      await app.send();
      await app.goTo('History');
      expect(await app.store.readAllHistory(), hasLength(1));
    });
  });
}
