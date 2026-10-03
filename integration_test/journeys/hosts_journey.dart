import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/journey_harness.dart';
import '../support/seed_data.dart';

/// Journey 7: see which hosts every environment points to, fix the gaps, note
/// what each one is for.
void defineHostsJourney(JourneyHarness Function() harness) {
  group('Hosts journey', () {
    Finder warning(String host) => find.byKey(Key('host-warning-$host'));

    String warningText(WidgetTester tester, String host) {
      final text = tester.widget<Text>(find.descendant(of: warning(host), matching: find.byType(Text)).last);
      return text.textSpan?.toPlainText() ?? text.data ?? '';
    }

    Future<Environment> storedEnvironment(AppDriver app, String id) async =>
        (await app.store.readEnvironments()).firstWhere((e) => e.id == id);

    /// The demo data with [change] applied to the stored environments/endpoints.
    Future<AppDriver> launchWith(
      WidgetTester tester, {
      List<Environment> Function(List<Environment>)? environments,
      List<Endpoint> extraEndpoints = const [],
      String activeEnvironmentId = 'dev',
    }) async {
      final store = await harness().newStore();
      await seedStore(store, activeEnvironmentId: activeEnvironmentId);
      if (environments != null) await store.writeEnvironments(environments(seedEnvironments));
      if (extraEndpoints.isNotEmpty) {
        final collections = await store.readCollections();
        await store.writeCollections(groups: collections.groups, endpoints: [...collections.endpoints, ...extraEndpoints]);
      }
      return harness().launchApp(tester, store: store);
    }

    journeyTest('the dialog lists every host with how many requests use it', (tester) async {
      final app = await harness().launchApp(tester);

      await app.openHostsDialog();

      for (final host in ['AUTH_HOST', 'MARKET_HOST', 'base_url']) {
        expect(find.byKey(Key('host-row-$host')), findsOneWidget, reason: host);
      }
      expect(find.descendant(of: find.byKey(const Key('host-row-base_url')), matching: find.text('Used by 5 requests')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('host-row-AUTH_HOST')), matching: find.text('Used by 0 requests')), findsOneWidget);
    });

    journeyTest('a host missing in QA is warned about, naming the environment', (tester) async {
      final app = await harness().launchApp(tester);

      await app.openHostsDialog();

      expect(warningText(tester, 'MARKET_HOST'), startsWith("MARKET_HOST isn't defined in QA."));
      expect(warning('AUTH_HOST'), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('host-cell-MARKET_HOST-qa')), matching: find.text('missing')), findsOneWidget);
    });

    journeyTest('typing the missing value clears the warning and saves it to QA', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openHostsDialog();

      await tester.enterText(find.byKey(const Key('host-field-MARKET_HOST-qa')), 'https://market.qa.test');
      await app.settle();

      expect(warning('MARKET_HOST'), findsNothing);
      expect(find.byKey(const Key('hosts-all-defined')), findsOneWidget);
      expect((await storedEnvironment(app, 'qa')).variables['MARKET_HOST']!.value, 'https://market.qa.test');
      expect((await storedEnvironment(app, 'dev')).variables['MARKET_HOST']!.value, 'https://market.dev.test');
    });

    journeyTest('clearing a cell removes the variable from that environment only and raises a warning', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openHostsDialog();

      await tester.enterText(find.byKey(const Key('host-field-AUTH_HOST-qa')), '');
      await app.settle();

      expect((await storedEnvironment(app, 'qa')).variables.containsKey('AUTH_HOST'), isFalse);
      expect((await storedEnvironment(app, 'dev')).variables.containsKey('AUTH_HOST'), isTrue);
      expect((await storedEnvironment(app, 'prod')).variables.containsKey('AUTH_HOST'), isTrue);
      expect(warningText(tester, 'AUTH_HOST'), startsWith("AUTH_HOST isn't defined in QA."));
    });

    journeyTest('a note is kept after closing and reopening the dialog and in the notes file', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openHostsDialog();

      await tester.enterText(find.byKey(const Key('host-note-AUTH_HOST')), 'Identity: login and PIN');
      await app.settle();
      await app.closeHostsDialog();
      await app.openHostsDialog();

      expect(tester.widget<TextField>(find.byKey(const Key('host-note-AUTH_HOST'))).controller!.text, 'Identity: login and PIN');
      expect(await app.store.readHostNotes(), {'AUTH_HOST': 'Identity: login and PIN'});
    });

    journeyTest('Add host plus a typed URL creates the variable, visible in the Environments editor', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openHostsDialog();

      await app.addHost('SEARCH_HOST');
      expect(find.byKey(const Key('host-row-SEARCH_HOST')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('host-field-SEARCH_HOST-dev')), 'https://search.dev.test');
      await app.settle();
      await app.closeHostsDialog();

      expect((await storedEnvironment(app, 'dev')).variables['SEARCH_HOST']!.value, 'https://search.dev.test');
      await app.goTo('Environments');
      expect(find.text('SEARCH_HOST'), findsOneWidget);
      expect(find.text('https://search.dev.test'), findsOneWidget);
    });

    journeyTest('a host added but never given a value is gone when the dialog is reopened', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openHostsDialog();
      await app.addHost('NEVER_USED');
      expect(find.byKey(const Key('host-row-NEVER_USED')), findsOneWidget);

      await app.closeHostsDialog();
      await app.openHostsDialog();

      expect(find.byKey(const Key('host-row-NEVER_USED')), findsNothing);
    });

    journeyTest('a used host missing in the active environment is flagged ACTIVE', (tester) async {
      final app = await launchWith(
        tester,
        activeEnvironmentId: 'qa',
        extraEndpoints: const [
          Endpoint(id: 'e-market', groupId: 'g-demo', name: 'Market', method: 'GET', url: '{{MARKET_HOST}}/offers'),
        ],
      );

      await app.openHostsDialog();

      expect(find.descendant(of: warning('MARKET_HOST'), matching: find.byKey(const Key('host-warning-active-tag'))), findsOneWidget);
    });

    journeyTest('the same warning has no ACTIVE tag while another environment is active', (tester) async {
      final app = await launchWith(
        tester,
        extraEndpoints: const [
          Endpoint(id: 'e-market', groupId: 'g-demo', name: 'Market', method: 'GET', url: '{{MARKET_HOST}}/offers'),
        ],
      );

      await app.openHostsDialog();

      expect(warning('MARKET_HOST'), findsOneWidget);
      expect(find.byKey(const Key('host-warning-active-tag')), findsNothing);
    });

    journeyTest('a secret variable that holds a URL never appears', (tester) async {
      final app = await launchWith(
        tester,
        environments: (envs) => [
          envs.first.copyWith(variables: {
            ...envs.first.variables,
            'SECRET_URL': const EnvironmentVariable(value: 'https://secret.internal.test', secret: true),
          }),
          ...envs.skip(1),
        ],
      );

      await app.openHostsDialog();

      expect(find.byKey(const Key('host-row-SECRET_URL')), findsNothing);
      expect(find.text('https://secret.internal.test'), findsNothing);
      expect(find.byKey(const Key('host-row-AUTH_HOST')), findsOneWidget);
    });

    journeyTest('Esc closes the dialog', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openHostsDialog();

      await app.pressEscape();

      expect(find.text('Hosts by environment'), findsNothing);
    });
  });
}
