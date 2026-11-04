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
        expect(find.byKey(ValueKey('step-node-$i')), findsOneWidget, reason: 'step $i');
      }
      expect(find.descendant(of: find.byKey(const ValueKey('step-node-0')), matching: find.text('Log in')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('step-node-2')), matching: find.text('List items')), findsOneWidget);
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

      // The flow runs on the canvas, so the header (and its session button) stays in view.
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
          steps: [FlowStep(endpointId: 'e-items', assertions: [Assertion(field: 'response.status', expected: '201')])],
        ),
      ]);
      await app.openFlow('f-assert');

      await app.runOpenFlow();

      expect(find.text('1 failed'), findsOneWidget);
      expect(find.text('Assertion Failure'), findsOneWidget);
    });

    journeyTest('a step with three assertions shows which held and which did not', (tester) async {
      final app = await launchWith(tester, flows: const [
        Flow(
          id: 'f-three',
          name: 'Three checks',
          steps: [
            FlowStep(endpointId: 'e-items', assertions: [
              Assertion(field: 'response.status', expected: '200'),
              Assertion(field: 'response.body.items.0.name', expected: 'Apple'),
              Assertion(field: 'response.body.items.1.name', expected: 'Banana'),
            ]),
          ],
        ),
      ]);
      await app.openFlow('f-three');

      await app.runOpenFlow();

      expect(find.text('1 failed'), findsOneWidget);
      expect(find.text('Assertion Failure'), findsOneWidget);
      expect(find.text('2/3 assertions'), findsOneWidget);
      // The failed step is already selected, its Run tab open in the side panel.
      await tester.tap(find.text('Assertions'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assertion-passed-0')), findsOneWidget);
      expect(find.byKey(const Key('assertion-passed-1')), findsOneWidget);
      expect(find.byKey(const Key('assertion-failed-2')), findsOneWidget);
      expect(find.textContaining('got "Pear"'), findsWidgets);
    });

    journeyTest('an assertion added in the editor is evaluated on the next run', (tester) async {
      final app = await launchWith(tester, flows: const [
        Flow(id: 'f-edit', name: 'Edit me', steps: [FlowStep(endpointId: 'e-items')]),
      ]);
      await app.openFlow('f-edit');

      // The assertions of a step are in its side panel, opened by selecting the node.
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('step-node-0')), matching: find.text('List items')));
      await tester.pumpAndSettle();
      await app.tapKey(const Key('add-assertion-0'));
      await app.runOpenFlow();

      // The editor proposes response.status == 200, which the demo route satisfies.
      expect(find.text('1 passed'), findsOneWidget);
      expect(find.text('1/1 assertions'), findsOneWidget);
    });

    journeyTest('connecting a field by dragging sends the extracted value', (tester) async {
      final app = await launchWith(
        tester,
        endpoints: const [
          Endpoint(id: 'e-owner', groupId: 'g-demo', name: 'Owner items', method: 'GET', url: '{{base_url}}/items?owner={{owner_id}}'),
        ],
        flows: const [
          Flow(
            id: 'f-drag',
            name: 'Drag',
            steps: [FlowStep(endpointId: 'e-login'), FlowStep(endpointId: 'e-me'), FlowStep(endpointId: 'e-owner')],
          ),
        ],
      );
      await app.openFlow('f-drag');

      // Send login and profile once, so the profile node lists its response fields (user, id).
      await app.tapKey(const ValueKey('run-until-1'));
      await app.tapKey(const Key('step-panel-close'));
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('step-field-pin-1-1'))));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byKey(const ValueKey('step-input-2-owner_id'))));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      await app.runOpenFlow();

      expect(find.text('3 passed'), findsOneWidget);
      expect(app.backend.calls.last.url, 'https://dev.api.test/items?owner=42');
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

      await app.tapKey(const Key('run-flow-button'));

      expect(app.backend.calls, hasLength(6));
      expect(find.text('3 passed'), findsOneWidget);
    });

    journeyTest('running a flow keeps the builder on screen', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openFlow('f-signup');
      await app.runOpenFlow();

      expect(find.byKey(const Key('flow-name-field')), findsOneWidget);
      expect(find.byKey(const Key('run-flow-button')), findsOneWidget);
      expect(find.byKey(const ValueKey('step-node-0')), findsOneWidget);
    });

    journeyTest('a flow built from scratch with the step picker runs', (tester) async {
      final app = await harness().launchApp(tester);
      await app.goTo('Flows');
      await app.tapKey(const Key('new-flow-button'));

      for (final endpoint in ['e-items', 'e-me']) {
        await app.tapKey(const Key('add-step-button'));
        await app.tapKey(ValueKey('add-step-picker-item-$endpoint'));
      }
      expect(find.byKey(const ValueKey('step-node-1')), findsOneWidget);

      await app.runOpenFlow();

      expect(find.text('2 passed'), findsOneWidget);
      expect(app.backend.calls.map((c) => c.uri.path), ['/items', '/me']);
    });
  });
}
