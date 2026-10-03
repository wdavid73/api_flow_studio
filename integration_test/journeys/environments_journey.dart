import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/journey_harness.dart';

/// Journey 4: `{{variables}}` resolve against the active environment.
void defineEnvironmentsJourney(JourneyHarness Function() harness) {
  group('Environments journey', () {
    journeyTest('a request goes out with the value of the active environment', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');

      await app.send();

      expect(app.backend.lastCall.url, 'https://dev.api.test/items');
      expect(app.backend.lastCall.variables['base_url'], 'https://dev.api.test');
    });

    journeyTest('switching the environment changes the URL that is sent, not the saved request', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');
      await app.send();

      await app.selectEnvironment('qa');
      await app.send();
      await app.selectEnvironment('prod');
      await app.send();

      expect(app.backend.calls.map((c) => c.url), [
        'https://dev.api.test/items',
        'https://qa.api.test/items',
        'https://api.test/items',
      ]);
      expect(tester.widget<TextField>(find.byKey(const Key('request-url-field'))).controller!.text, '{{base_url}}/items');
    });

    journeyTest('a variable that is not defined is sent as it was written', (tester) async {
      final app = await harness().launchApp(tester);

      await app.setUrl('{{not_defined}}/items');
      await app.send();

      expect(app.backend.lastCall.url, '{{not_defined}}/items');
    });

    journeyTest('a variable added in the Environments screen is used by the next send', (tester) async {
      final app = await harness().launchApp(tester);

      await app.goTo('Environments');
      await app.tapKey(const Key('add-variable-button'));
      await tester.enterText(find.byKey(const Key('variable-name-field')).last, 'api_prefix');
      await app.settle();
      await tester.enterText(find.byKey(const Key('variable-value-field')).last, 'v2');
      await app.settle();

      await app.goTo('Workspace');
      await app.setUrl('{{base_url}}/{{api_prefix}}/items');
      await app.send();

      expect(app.backend.lastCall.url, 'https://dev.api.test/v2/items');
    });

    journeyTest('a new environment can be created and made active', (tester) async {
      final app = await harness().launchApp(tester);

      await app.goTo('Environments');
      await app.tapKey(const Key('new-environment-button'));
      final created = (await app.store.readEnvironments()).firstWhere((e) => e.name == 'New Environment');
      await app.goTo('Workspace');
      await app.selectEnvironment(created.id);

      await app.setUrl('{{base_url}}/items');
      await app.send();

      // The new environment has no variables, so nothing resolves.
      expect(app.backend.lastCall.url, '{{base_url}}/items');
    });
  });
}
