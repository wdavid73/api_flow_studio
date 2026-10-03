import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/journey_harness.dart';
import '../support/seed_data.dart';

/// Journey 6: chain saved requests into a flow, run it, read the result.
void defineFlowJourney(JourneyHarness Function() harness) {
  group('Flow journey', () {
    /// A store with the standard demo data plus [flows] and extra [endpoints].
    Future<AppDriver> launchWith(
      WidgetTester tester, {
      List<Flow> flows = const [seedFlow],
      List<Endpoint> endpoints = const [],
    }) async {
      final store = await harness().newStore();
      await seedStore(store);
      await store.writeFlows(flows);
      if (endpoints.isNotEmpty) {
        final collections = await store.readCollections();
        await store.writeCollections(groups: collections.groups, endpoints: [...collections.endpoints, ...endpoints]);
      }
      return harness().launchApp(tester, store: store);
    }

    journeyTest('the seeded flow shows its three steps in order', (tester) async {
      final app = await harness().launchApp(tester);

      await app.openFlow('f-signup');

      for (final i in [0, 1, 2]) {
        expect(find.byKey(ValueKey('step-card-$i')), findsOneWidget, reason: 'step $i');
      }
      expect(find.descendant(of: find.byKey(const ValueKey('step-card-0')), matching: find.text('Log in')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('step-card-2')), matching: find.text('List items')), findsOneWidget);
    });

    journeyTest('running a flow where every step passes reports 3 passed', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openFlow('f-signup');

      await app.runOpenFlow();

      expect(find.text('3 passed'), findsOneWidget);
      expect(find.text('0 failed'), findsOneWidget);
      expect(find.text('0 skipped'), findsOneWidget);
      expect(app.backend.calls.map((c) => '${c.method} ${c.uri.path}'), ['POST /login', 'GET /me', 'GET /items']);
      expect(find.byKey(const Key('run-summary-total')), findsOneWidget);
    });

    journeyTest('a login step inside a flow leaves the session ready for the next step', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openFlow('f-signup');

      await app.runOpenFlow();

      expect(app.backend.calls[1].header('Authorization'), 'Bearer $fakeAccessToken');
      expect(app.backend.calls[2].header('Authorization'), 'Bearer $fakeAccessToken');

      // The run view covers the header; back in the builder it shows the session.
      await app.tapKey(const Key('run-view-back-button'));
      expect(find.descendant(of: find.byKey(const Key('session-button')), matching: find.text('Expires in 12 min')), findsOneWidget);
    });

    journeyTest('a failing step is reported and the next one is skipped', (tester) async {
      final app = await launchWith(tester, flows: const [
        Flow(
          id: 'f-fail',
          name: 'Breaks in the middle',
          steps: [FlowStep(endpointId: 'e-items'), FlowStep(endpointId: 'e-boom'), FlowStep(endpointId: 'e-me')],
        ),
      ]);
      await app.openFlow('f-fail');

      await app.runOpenFlow();

      expect(find.text('1 passed'), findsOneWidget);
      expect(find.text('1 failed'), findsOneWidget);
      expect(find.text('1 skipped'), findsOneWidget);
      expect(app.backend.calls, hasLength(2)); // the third step never ran
      expect(find.text('Skipped'), findsOneWidget);
      // The failed step is selected and explains itself.
      expect(find.text('Error Details'), findsOneWidget);
      expect(find.text('Network Error'), findsOneWidget);
    });

    journeyTest('an assertion that does not hold fails the step', (tester) async {
      final app = await launchWith(tester, flows: const [
        Flow(
          id: 'f-assert',
          name: 'Expects 201',
          steps: [FlowStep(endpointId: 'e-items', assertField: 'response.status', assertExpected: '201')],
        ),
      ]);
      await app.openFlow('f-assert');

      await app.runOpenFlow();

      expect(find.text('1 failed'), findsOneWidget);
      expect(find.text('Assertion Failure'), findsOneWidget);
    });

    journeyTest('a value extracted from one step is used in the next one', (tester) async {
      final app = await launchWith(
        tester,
        endpoints: const [
          Endpoint(id: 'e-use-token', groupId: 'g-demo', name: 'Use token', method: 'GET', url: '{{base_url}}/items?token={{tok}}'),
        ],
        flows: const [
          Flow(
            id: 'f-chain',
            name: 'Chain',
            steps: [
              FlowStep(endpointId: 'e-login', extract: {'tok': 'response.body.data.refreshToken'}),
              FlowStep(endpointId: 'e-use-token'),
            ],
          ),
        ],
      );
      await app.openFlow('f-chain');

      await app.runOpenFlow();

      expect(find.text('2 passed'), findsOneWidget);
      expect(app.backend.calls[1].url, 'https://dev.api.test/items?token=$fakeRefreshToken');
    });

    journeyTest('Re-run runs the flow again from the start', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openFlow('f-signup');
      await app.runOpenFlow();
      expect(app.backend.calls, hasLength(3));

      await app.tapKey(const Key('re-run-flow-button'));

      expect(app.backend.calls, hasLength(6));
      expect(find.text('3 passed'), findsOneWidget);
    });

    journeyTest('Back from the run view returns to the flow builder', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openFlow('f-signup');
      await app.runOpenFlow();

      await app.tapKey(const Key('run-view-back-button'));

      expect(find.byKey(const Key('flow-name-field')), findsOneWidget);
      expect(find.byKey(const Key('run-flow-button')), findsOneWidget);
    });

    journeyTest('a flow built from scratch with the step picker runs', (tester) async {
      final app = await harness().launchApp(tester);
      await app.goTo('Flows');
      await app.tapKey(const Key('new-flow-button'));

      for (final endpoint in ['e-items', 'e-me']) {
        await app.tapKey(const Key('add-step-button'));
        await app.tapKey(ValueKey('add-step-picker-item-$endpoint'));
      }
      expect(find.byKey(const ValueKey('step-card-1')), findsOneWidget);

      await app.runOpenFlow();

      expect(find.text('2 passed'), findsOneWidget);
      expect(app.backend.calls.map((c) => c.uri.path), ['/items', '/me']);
    });
  });
}
