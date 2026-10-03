import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/journey_harness.dart';

/// Journey 10: working in a production environment is unmistakable.
void defineProductionJourney(JourneyHarness Function() harness) {
  group('Production journey', () {
    double stripHeight(WidgetTester tester) => tester.getSize(find.byKey(const Key('active-environment-strip'))).height;

    Color? pillFill(WidgetTester tester, String id) =>
        (tester.widget<Container>(find.byKey(Key('env-pill-$id'))).decoration as BoxDecoration?)?.color;

    journeyTest('with a non-production environment active there is no red strip', (tester) async {
      await harness().launchApp(tester);

      expect(stripHeight(tester), 0);
      expect(pillFill(tester, 'dev'), AppColors.primary);
    });

    journeyTest('activating Prod shows the red strip and a red pill button', (tester) async {
      final app = await harness().launchApp(tester);

      await app.selectEnvironment('prod');

      expect(stripHeight(tester), 3);
      expect(tester.widget<Container>(find.byKey(const Key('active-environment-strip'))).color, AppColors.error);
      expect(pillFill(tester, 'prod'), AppColors.error);
      expect(pillFill(tester, 'dev'), isNull);
    });

    journeyTest('going back to another environment removes the strip', (tester) async {
      final app = await harness().launchApp(tester);
      await app.selectEnvironment('prod');

      await app.selectEnvironment('qa');

      expect(stripHeight(tester), 0);
      expect(pillFill(tester, 'qa'), AppColors.primary);
    });

    journeyTest('the strip stays across screens', (tester) async {
      final app = await harness().launchApp(tester);
      await app.selectEnvironment('prod');

      for (final destination in ['Environments', 'Flows', 'History', 'Workspace']) {
        await app.goTo(destination);
        expect(stripHeight(tester), 3, reason: destination);
      }
    });

    journeyTest('the Environments list tags Prod and marks only the active environment', (tester) async {
      final app = await harness().launchApp(tester);
      await app.selectEnvironment('prod');

      await app.goTo('Environments');

      expect(find.byKey(const Key('env-prod-tag-prod')), findsOneWidget);
      expect(find.byKey(const Key('env-prod-tag-dev')), findsNothing);
      expect(find.byKey(const Key('env-active-tag-prod')), findsOneWidget);
      expect(find.byKey(const Key('env-active-tag-dev')), findsNothing);
      expect(tester.widget<CircleAvatar>(find.byKey(const Key('env-dot-prod'))).backgroundColor, AppColors.error);
    });

    journeyTest('a request sent while Prod is active goes to the production URL', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');
      await app.selectEnvironment('prod');

      await app.send();

      expect(app.backend.lastCall.url, 'https://api.test/items');
    });

    journeyTest('the Hosts dialog marks the Prod column', (tester) async {
      final app = await harness().launchApp(tester);

      await app.tapKey(const Key('hosts-button'));

      expect(find.byKey(const Key('host-env-prod-tag-prod')), findsOneWidget);
      expect(find.byKey(const Key('host-env-prod-tag-dev')), findsNothing);
    });
  });
}
