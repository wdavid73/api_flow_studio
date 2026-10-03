import 'package:api_flow_studio/ui/shell/app_header.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/journey_harness.dart';

/// Journey 1: the app opens on the Workspace, every destination can be reached
/// and left, and the header shows what it should.
void defineNavigationJourney(JourneyHarness Function() harness) {
  group('Navigation journey', () {
    testWidgets('opens on the Workspace with both header buttons', (tester) async {
      final app = await harness().launchApp(tester);

      expect(find.byKey(const Key('workspace-request-pane')), findsOneWidget);
      expect(find.byKey(const Key('request-url-field')), findsOneWidget);
      expect(find.byKey(const Key('hosts-button')), findsOneWidget);
      expect(find.byKey(const Key('session-button')), findsOneWidget);
      expect(app.backend.calls, isEmpty);
    });

    testWidgets('every destination can be reached and the Workspace comes back', (tester) async {
      final app = await harness().launchApp(tester);

      await app.goTo('Environments');
      expect(find.text('ENVIRONMENTS'), findsOneWidget);

      await app.goTo('Flows');
      expect(find.text('FLOWS'), findsOneWidget);

      await app.goTo('History');
      expect(find.byKey(const Key('history-screen')), findsOneWidget);

      await app.goTo('Workspace');
      expect(find.byKey(const Key('workspace-request-pane')), findsOneWidget);
    });

    testWidgets('the environment pill lists the seeded environments with Dev active', (tester) async {
      await harness().launchApp(tester);

      for (final id in ['dev', 'qa', 'prod']) {
        expect(find.byKey(Key('env-pill-$id')), findsOneWidget, reason: id);
      }
      Color? fill(String id) =>
          (tester.widget<Container>(find.byKey(Key('env-pill-$id'))).decoration as BoxDecoration?)?.color;

      expect(fill('dev'), AppColors.primary);
      expect(fill('qa'), isNull);
      expect(find.byType(AppHeader), findsOneWidget);
    });

    testWidgets('the seeded collection is in the sidebar', (tester) async {
      final app = await harness().launchApp(tester);

      await app.expandFolder('g-demo');

      expect(find.byKey(const ValueKey('endpoint-row-e-items')), findsOneWidget);
      expect(find.byKey(const ValueKey('endpoint-row-e-login')), findsOneWidget);
    });
  });
}
