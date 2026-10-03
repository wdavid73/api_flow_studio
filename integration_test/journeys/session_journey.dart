import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/journey_harness.dart';
import '../support/seed_data.dart';

/// Journey 5: log in once, and the rest of the requests carry the token.
void defineSessionJourney(JourneyHarness Function() harness) {
  group('Session journey', () {
    Finder inSessionButton(String text) =>
        find.descendant(of: find.byKey(const Key('session-button')), matching: find.text(text));

    /// Logs in on the active environment: the demo `/login` answers with tokens.
    Future<AppDriver> loggedIn(WidgetTester tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-login');
      await app.send();
      return app;
    }

    journeyTest('before logging in there is no token and /me is refused', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-me');

      await app.send();

      expect(inSessionButton('No token'), findsOneWidget);
      expect(app.backend.lastCall.header('Authorization'), isNull);
      expect(find.descendant(of: app.responsePane, matching: find.text('401')), findsOneWidget);
    });

    journeyTest('a login captures the tokens of the active environment and says so', (tester) async {
      await loggedIn(tester);

      expect(inSessionButton('Expires in 12 min'), findsOneWidget);
      expect(inSessionButton('Authorization: Bearer'), findsOneWidget);
      expect(find.text('Tokens captured for Dev'), findsOneWidget);
    });

    journeyTest('the toast never shows a token', (tester) async {
      await loggedIn(tester);

      final toast = tester.widget<Text>(find.descendant(of: find.byKey(const Key('toast-pill')), matching: find.byType(Text)));

      expect(toast.data, 'Tokens captured for Dev');
      expect(toast.data, isNot(contains(fakeAccessToken)));
      expect(toast.data, isNot(contains(fakeRefreshToken)));
    });

    journeyTest('the next request carries the Bearer token and is accepted', (tester) async {
      final app = await loggedIn(tester);

      await app.openRequest('e-me');
      await app.send();

      expect(app.backend.lastCall.header('Authorization'), 'Bearer $fakeAccessToken');
      expect(find.descendant(of: app.responsePane, matching: find.text('200')), findsOneWidget);
    });

    journeyTest('another environment has its own, empty session', (tester) async {
      final app = await loggedIn(tester);
      await app.openRequest('e-me');

      await app.selectEnvironment('qa');
      await app.send();

      expect(inSessionButton('No token'), findsOneWidget);
      expect(app.backend.lastCall.header('Authorization'), isNull);
      expect(find.descendant(of: app.responsePane, matching: find.text('401')), findsOneWidget);

      await app.selectEnvironment('dev');
      await app.send();

      expect(inSessionButton('Expires in 12 min'), findsOneWidget);
      expect(app.backend.lastCall.header('Authorization'), 'Bearer $fakeAccessToken');
    });

    journeyTest('Clear tokens removes the header again and keeps the switches', (tester) async {
      final app = await loggedIn(tester);

      await app.tapKey(const Key('session-button'));
      await app.tapKey(const Key('session-clear-button'));
      await app.pressEscape();
      await app.openRequest('e-me');
      await app.send();

      expect(inSessionButton('No token'), findsOneWidget);
      expect(app.backend.lastCall.header('Authorization'), isNull);

      await app.tapKey(const Key('session-button'));
      expect(tester.widget<Checkbox>(find.byKey(const Key('session-attach-checkbox'))).value, isTrue);
      expect(tester.widget<Checkbox>(find.byKey(const Key('session-capture-checkbox'))).value, isTrue);
    });

    journeyTest('a token typed by hand is used too', (tester) async {
      final app = await harness().launchApp(tester);
      await app.tapKey(const Key('session-button'));
      await tester.enterText(find.byKey(const Key('session-access-field')), 'typed-by-hand');
      await app.settle();
      await app.pressEscape();
      await app.openRequest('e-me');

      await app.send();

      expect(app.backend.lastCall.header('Authorization'), 'Bearer typed-by-hand');
      expect(inSessionButton('Token saved'), findsOneWidget);
    });

    journeyTest('with Send Authorization off the token is kept but not sent', (tester) async {
      final app = await loggedIn(tester);
      await app.tapKey(const Key('session-button'));
      await app.tapKey(const Key('session-attach-checkbox'));
      await app.pressEscape();
      await app.openRequest('e-me');

      await app.send();

      expect(app.backend.lastCall.header('Authorization'), isNull);
      expect(inSessionButton('Expires in 12 min'), findsOneWidget);
    });

    journeyTest('the copied curl carries the session header', (tester) async {
      final app = await loggedIn(tester);
      await app.openRequest('e-me');

      await app.tapKey(const Key('copy-curl-button'));

      expect(app.clipboard, contains("-H 'Authorization: Bearer $fakeAccessToken'"));
      expect(app.clipboard, contains("'https://dev.api.test/me'"));
    });

    journeyTest('a request with its own Authorization header keeps it', (tester) async {
      final store = await harness().newStore();
      await seedStore(store);
      final collections = await store.readCollections();
      await store.writeCollections(
        groups: collections.groups,
        endpoints: [
          ...collections.endpoints,
          const Endpoint(
            id: 'e-own-auth',
            groupId: 'g-demo',
            name: 'Own auth',
            method: 'GET',
            url: '{{base_url}}/me',
            headers: [KeyValueEntry(key: 'Authorization', value: 'Basic mine')],
          ),
        ],
      );
      final app = await harness().launchApp(tester, store: store);
      await app.openRequest('e-login');
      await app.send();

      await app.openRequest('e-own-auth');
      await app.send();

      expect(app.backend.lastCall.header('Authorization'), 'Basic mine');
    });

    journeyTest('the session label turns to expired when the token ages', (tester) async {
      final app = await loggedIn(tester);
      expect(inSessionButton('Expires in 12 min'), findsOneWidget);

      app.clock = app.clock.add(const Duration(minutes: 13));
      await app.selectEnvironment('qa');
      await app.selectEnvironment('dev');

      expect(inSessionButton('Token expired'), findsOneWidget);
    });
  });
}
