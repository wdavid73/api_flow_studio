import 'package:api_flow_studio/ui/theme/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/journey_harness.dart';

/// Journey 2: build a request, send it, read the response, copy it.
void defineSendRequestJourney(JourneyHarness Function() harness) {
  group('Send request journey', () {
    journeyTest('a saved request sent to /items shows status, time and body', (tester) async {
      final app = await harness().launchApp(tester);

      await app.openRequest('e-items');
      await app.send();

      expect(app.backend.calls, hasLength(1));
      expect(app.backend.lastCall.method, 'GET');
      expect(app.backend.lastCall.url, 'https://dev.api.test/items');

      expect(find.descendant(of: app.responsePane, matching: find.text('200')), findsOneWidget);
      expect(find.descendant(of: app.responsePane, matching: find.text('5 ms')), findsOneWidget);
      expect(find.descendant(of: app.responsePane, matching: find.textContaining('Apple', findRichText: true)), findsOneWidget);
    });

    journeyTest('Copy puts the response body on the clipboard and says so', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');
      await app.send();

      await app.tapKey(const Key('copy-body-button'));

      expect(app.clipboard, contains('Apple'));
      expect(app.clipboard, contains('Pear'));
      expect(find.text('Response copied'), findsOneWidget);
    });

    journeyTest('a request made from scratch in a new folder can be saved and sent', (tester) async {
      final app = await harness().launchApp(tester);

      await app.createFolder('My API');
      await app.addRequestIn('My API');
      await app.setUrl('{{base_url}}/items');
      await app.save();
      await app.send();

      expect(find.byKey(const Key('request-header-kicker')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('request-header-kicker'))).data, 'MY API');
      expect(app.backend.lastCall.url, 'https://dev.api.test/items');
      expect(find.descendant(of: app.responsePane, matching: find.text('200')), findsOneWidget);
    });

    journeyTest('a transport error is shown as an error, not as a status', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-boom');

      await app.send();

      expect(find.byKey(const Key('response-error')), findsOneWidget);
      expect(find.textContaining('Connection refused'), findsOneWidget);
      expect(find.descendant(of: app.responsePane, matching: find.byType(StatusBadge)), findsNothing);
    });

    journeyTest('a 500 answer is shown with its status', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-flaky');

      await app.send();

      expect(find.descendant(of: app.responsePane, matching: find.text('500')), findsOneWidget);
      expect(find.byKey(const Key('response-error')), findsNothing);
    });

    journeyTest('an unsaved draft still sends, but records no history', (tester) async {
      final app = await harness().launchApp(tester);

      await app.setUrl('{{base_url}}/items');
      await app.send();

      expect(app.backend.calls, hasLength(1));
      await app.openResponseHistoryTab();
      expect(find.byKey(const Key('history-unsaved-state')), findsOneWidget);
      await app.goTo('History');
      expect(find.byKey(const Key('history-screen-empty')), findsOneWidget);
    });
  });
}
