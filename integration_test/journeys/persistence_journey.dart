import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/disk_harness.dart';
import '../support/fixtures.dart';
import '../support/journey_harness.dart';

/// Journey 8: close the app and open it again; what was stored is still there,
/// what was only in memory (the session) is not.
void definePersistenceJourney(JourneyHarness Function() harness) {
  group('Persistence journey', () {
    journeyTest('folder, request, variable, flow and host note survive a restart', (tester) async {
      final app = await harness().launchApp(tester);

      // A folder with a request in it.
      await app.createFolder('Payments');
      await app.addRequestIn('Payments');
      await app.setUrl('{{base_url}}/pay');
      await app.save();

      // A variable on the active environment.
      await app.goTo('Environments');
      await app.tapKey(const Key('add-variable-button'));
      await tester.enterText(find.byKey(const Key('variable-name-field')).last, 'api_prefix');
      await app.settle();
      await tester.enterText(find.byKey(const Key('variable-value-field')).last, 'v2');
      await app.settle();

      // A flow.
      await app.goTo('Flows');
      await app.tapKey(const Key('new-flow-button'));
      await tester.enterText(find.byKey(const Key('flow-name-field')), 'Checkout flow');
      await app.settle();

      // A host note.
      await app.goTo('Workspace');
      await app.openHostsDialog();
      await tester.enterText(find.byKey(const Key('host-note-AUTH_HOST')), 'Identity service');
      await app.settle();
      await app.closeHostsDialog();

      await app.restart();

      expect(find.text('Payments'), findsOneWidget);
      final collections = await app.store.readCollections();
      expect(collections.endpoints.where((e) => e.url == '{{base_url}}/pay'), hasLength(1));

      await app.goTo('Environments');
      expect(find.text('api_prefix'), findsOneWidget);
      expect(find.text('v2'), findsOneWidget);

      await app.goTo('Flows');
      expect(find.text('Checkout flow'), findsWidgets);

      await app.goTo('Workspace');
      await app.openHostsDialog();
      expect(tester.widget<TextField>(find.byKey(const Key('host-note-AUTH_HOST'))).controller!.text, 'Identity service');
    });

    journeyTest('the history survives a restart', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');
      await app.send();

      await app.restart();
      await app.goTo('History');

      expect(find.textContaining('/items'), findsWidgets);
    });

    journeyTest('the session does not survive a restart', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-login');
      await app.send();
      expect(find.descendant(of: find.byKey(const Key('session-button')), matching: find.text('Expires in 12 min')), findsOneWidget);

      await app.restart();

      expect(find.descendant(of: find.byKey(const Key('session-button')), matching: find.text('No token')), findsOneWidget);
      await app.openRequest('e-me');
      await app.send();
      expect(app.backend.lastCall.header('Authorization'), isNull);
    });

    journeyTest('the session itself is never written to disk', (tester) async {
      final h = harness();
      final app = await h.launchApp(tester);
      await app.openRequest('e-login');
      await app.send();
      await app.openRequest('e-me');
      await app.send();

      if (h is! DiskHarness) return; // only the disk-backed run has files to read
      final files = h.lastDirectory!.listSync(recursive: true).whereType<File>().toList();
      final names = files.map((f) => f.uri.pathSegments.last).toSet();
      expect(names, containsAll(['projects.json', 'environments.json', 'collections.json', 'history.json']));
      // history.json keeps raw response bodies by design (a login response
      // included), so it is the one file that can contain a token the server sent.
      for (final file in files.where((f) => !f.path.endsWith('history.json'))) {
        final text = file.readAsStringSync();
        expect(text, isNot(contains(fakeAccessToken)), reason: file.path);
        expect(text, isNot(contains(fakeRefreshToken)), reason: file.path);
      }
    });
  });
}
