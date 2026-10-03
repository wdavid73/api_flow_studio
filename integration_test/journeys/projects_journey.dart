import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/disk_harness.dart';
import '../support/fixtures.dart';
import '../support/journey_harness.dart';

bool _isEnvironmentRow(Widget widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('env-list-item-');
}

/// Journey 11: work on several projects, each with its own data.
void defineProjectsJourney(JourneyHarness Function() harness) {
  group('Projects journey', () {
    Finder inSessionButton(String text) =>
        find.descendant(of: find.byKey(const Key('session-button')), matching: find.text(text));

    /// The demo data lives in "Default"; "fin_track_pro" is a second, empty project.
    Future<AppDriver> twoProjects(WidgetTester tester) async {
      final app = await harness().launchApp(tester);
      await app.createProject('fin_track_pro');
      return app;
    }

    journeyTest('the app starts on one project, with the demo data and nothing to delete', (tester) async {
      final app = await harness().launchApp(tester);

      expect(app.projectLabel('Default'), findsOneWidget);
      expect(find.text('Demo API'), findsOneWidget);
      await app.openProjectMenu();
      expect(find.byKey(const Key('new-project-button')), findsOneWidget);
      expect(find.byKey(const Key('delete-project-button')), findsNothing);
    });

    journeyTest('a new project is empty and becomes the active one', (tester) async {
      final app = await twoProjects(tester);

      expect(app.projectLabel('fin_track_pro'), findsOneWidget);
      expect(find.text('Project "fin_track_pro" created'), findsOneWidget);
      expect(find.text('Demo API'), findsNothing);
      expect(find.byKey(const Key('environment-switcher')), findsNothing);
      await app.goTo('Flows');
      expect(find.byKey(const ValueKey('flow-list-item-f-signup')), findsNothing);
    });

    journeyTest('what is created in one project is not in the other, and comes back', (tester) async {
      final app = await twoProjects(tester);
      await app.createFolder('Payments');
      await app.goTo('Flows');
      await app.tapKey(const Key('new-flow-button'));
      await tester.enterText(find.byKey(const Key('flow-name-field')), 'Checkout flow');
      await app.settle();
      await app.goTo('Environments');
      await app.tapKey(const Key('new-environment-button'));
      await app.goTo('Workspace');

      await app.switchProject('Default');

      expect(app.projectLabel('Default'), findsOneWidget);
      expect(find.text('Demo API'), findsOneWidget);
      expect(find.text('Payments'), findsNothing);
      await app.goTo('Flows');
      expect(find.byKey(const ValueKey('flow-list-item-f-signup')), findsOneWidget);
      expect(find.text('Checkout flow'), findsNothing);
      await app.goTo('Environments');
      for (final id in ['dev', 'qa', 'prod']) {
        expect(find.byKey(ValueKey('env-list-item-$id')), findsOneWidget, reason: id);
      }
      expect(find.byWidgetPredicate(_isEnvironmentRow), findsNWidgets(3)); // the one made in fin_track_pro is not here

      await app.goTo('Workspace');
      await app.switchProject('fin_track_pro');

      expect(find.text('Payments'), findsOneWidget);
      expect(find.text('Demo API'), findsNothing);
      await app.goTo('Flows');
      expect(find.text('Checkout flow'), findsWidgets);
    });

    journeyTest('a request sent in one project is in that project\'s history only', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-items');
      await app.send();
      await app.createProject('fin_track_pro');

      await app.goTo('History');
      expect(find.byKey(const Key('history-screen')), findsOneWidget);
      expect(find.text('List items'), findsNothing);

      await app.goTo('Workspace');
      await app.switchProject('Default');
      await app.goTo('History');
      expect(find.text('List items'), findsOneWidget);
    });

    journeyTest('the request being edited does not follow to the other project', (tester) async {
      final app = await twoProjects(tester);
      await app.switchProject('Default');
      await app.openRequest('e-items');
      expect(tester.widget<TextField>(find.byKey(const Key('request-url-field'))).controller!.text, '{{base_url}}/items');

      await app.switchProject('fin_track_pro');

      expect(tester.widget<TextField>(find.byKey(const Key('request-url-field'))).controller!.text, isEmpty);
    });

    journeyTest('a token captured in one project is not sent from the other', (tester) async {
      final app = await harness().launchApp(tester);
      await app.openRequest('e-login');
      await app.send();
      expect(inSessionButton('Expires in 12 min'), findsOneWidget);

      await app.createProject('fin_track_pro');

      expect(inSessionButton('No token'), findsOneWidget);
      await app.goTo('Workspace');
      await app.switchProject('Default');
      expect(inSessionButton('Expires in 12 min'), findsOneWidget);
      expect(app.backend.calls.map((c) => c.uri.path), ['/login']);
    });

    journeyTest('renaming keeps the data and updates the header', (tester) async {
      final app = await harness().launchApp(tester);

      await app.renameActiveProject('commodo');

      expect(app.projectLabel('commodo'), findsOneWidget);
      expect(app.projectLabel('Default'), findsNothing);
      expect(find.text('Demo API'), findsOneWidget);
      expect(find.text('Project renamed to "commodo"'), findsOneWidget);
    });

    journeyTest('a name already taken is refused and nothing changes', (tester) async {
      final app = await twoProjects(tester);

      await app.openProjectMenu();
      await app.tapKey(const Key('new-project-button'));
      await tester.enterText(find.byKey(const Key('project-name-field')), 'default');
      await app.tapKey(const Key('project-dialog-confirm-button'));

      expect(find.text('A project with that name already exists.'), findsOneWidget);
      await app.tapKey(const Key('project-dialog-cancel-button'));
      expect(app.projectLabel('fin_track_pro'), findsOneWidget);
      expect(await app.projects.projects(), hasLength(2));
    });

    journeyTest('deleting asks first, then removes the project and shows another one', (tester) async {
      final app = await twoProjects(tester);

      await app.openProjectMenu();
      await app.tapKey(const Key('delete-project-button'));
      expect(find.textContaining('fin_track_pro'), findsWidgets);
      await app.tapKey(const Key('delete-project-cancel-button'));
      expect(await app.projects.projects(), hasLength(2));

      await app.deleteActiveProject();

      expect(await app.projects.projects(), hasLength(1));
      expect(app.projectLabel('Default'), findsOneWidget);
      expect(find.text('Demo API'), findsOneWidget);
      await app.openProjectMenu();
      expect(find.byKey(const Key('delete-project-button')), findsNothing);
    });

    journeyTest('after a restart the projects, the active one and their data are all there', (tester) async {
      final app = await twoProjects(tester);
      await app.createFolder('Payments');

      await app.restart();

      expect(app.projectLabel('fin_track_pro'), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
      await app.switchProject('Default');
      expect(find.text('Demo API'), findsOneWidget);
      expect(find.text('Payments'), findsNothing);

      await app.restart();

      expect(app.projectLabel('Default'), findsOneWidget);
    });

    journeyTest('on disk each project keeps its files in its own folder, removed with the project', (tester) async {
      final h = harness();
      final app = await h.launchApp(tester);
      if (h is! DiskHarness) return; // only the disk-backed run has files to look at
      final root = h.lastDirectory!;
      final defaultId = (await app.projects.activeProject())!.id;
      await app.createProject('fin_track_pro');
      final otherId = (await app.projects.activeProject())!.id;
      await app.createFolder('Payments');

      expect(File('${root.path}/projects/$defaultId/collections.json').existsSync(), isTrue);
      expect(File('${root.path}/projects/$otherId/collections.json').existsSync(), isTrue);
      expect(File('${root.path}/collections.json').existsSync(), isFalse);

      await app.deleteActiveProject();

      expect(Directory('${root.path}/projects/$otherId').existsSync(), isFalse);
      expect(Directory('${root.path}/projects/$defaultId').existsSync(), isTrue);
      expect(fakeAccessToken, isNotEmpty); // keeps the fixtures import honest
    });
  });
}
