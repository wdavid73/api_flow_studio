import 'dart:convert';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/workspace/workspace_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fixtures.dart';
import '../support/journey_harness.dart';

bool _isEnvironmentRow(Widget widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('env-list-item-');
}

/// Journey 12: pass a project on to someone else as a file and open it again.
void defineWorkspaceTransferJourney(JourneyHarness Function() harness) {
  group('Workspace transfer journey', () {
    /// The demo project with a secret key in Dev and a note on a host, which the
    /// standard demo data does not have.
    Future<AppDriver> demoWithSecretsAndNotes(WidgetTester tester) async {
      final app = await harness().launchApp(tester);
      final store = app.store;
      final environments = await store.readEnvironments();
      await store.writeEnvironments([
        environments.first.copyWith(variables: {
          ...environments.first.variables,
          'api_key': const EnvironmentVariable(value: 'S3CR3T-DEV-KEY', secret: true),
        }),
        ...environments.skip(1),
      ]);
      await store.writeHostNotes({'AUTH_HOST': 'Identity service'});
      await app.restart();
      return app;
    }

    journeyTest('exporting saves a file named after the project, with everything in it', (tester) async {
      final app = await demoWithSecretsAndNotes(tester);
      await app.renameActiveProject('commodo');

      await app.exportActiveWorkspace();

      expect(app.files.savedName, 'commodo.workspace.json');
      expect(find.text('Workspace "commodo" exported — secrets are not included'), findsOneWidget);
      final file = WorkspaceFile.parse(app.files.savedText!);
      expect(file.name, 'commodo');
      expect(file.environments.map((e) => e.name), ['Dev', 'QA', 'Prod']);
      expect(file.endpoints, hasLength(5));
      expect(file.flows.single.name, 'Sign up');
      expect(file.hostNotes, {'AUTH_HOST': 'Identity service'});
    });

    journeyTest('the file carries no secret value, no token and no history', (tester) async {
      final app = await demoWithSecretsAndNotes(tester);
      await app.openRequest('e-login');
      await app.send(); // captures a token in the session and records history
      expect(await app.store.readAllHistory(), isNotEmpty);

      await app.exportActiveWorkspace();

      final text = app.files.savedText!;
      expect(text, isNot(contains('S3CR3T-DEV-KEY')));
      expect(text, isNot(contains(fakeAccessToken)));
      expect(text, isNot(contains(fakeRefreshToken)));
      expect(jsonDecode(text), isNot(contains('history')));
      final key = WorkspaceFile.parse(text).environments.first.variables['api_key']!;
      expect(key.secret, isTrue);
      expect(key.value, isEmpty);
    });

    journeyTest('importing that file opens a copy as a new project, saying what is left to fill in', (tester) async {
      final app = await demoWithSecretsAndNotes(tester);
      await app.exportActiveWorkspace();

      await app.importWorkspaceFile(app.files.savedText!);

      expect(app.projectLabel('Default (2)'), findsOneWidget);
      expect(find.text('Imported "Default (2)" — 1 secret value to fill in'), findsOneWidget);
      expect(find.text('Demo API'), findsOneWidget);
      expect((await app.projects.projects()).map((p) => p.name), ['Default', 'Default (2)']);
      await app.goTo('Environments');
      expect(find.byWidgetPredicate(_isEnvironmentRow), findsNWidgets(3));
      await app.goTo('Flows');
      expect(find.text('Sign up'), findsWidgets);
    });

    journeyTest('the copy has the same content, new ids, empty secrets and no active environment', (tester) async {
      final app = await demoWithSecretsAndNotes(tester);
      await app.exportActiveWorkspace();
      await app.importWorkspaceFile(app.files.savedText!);

      final copy = await app.activeStore();
      final environments = await copy.readEnvironments();
      final collections = await copy.readCollections();

      expect(environments.map((e) => e.name), ['Dev', 'QA', 'Prod']);
      expect(environments.map((e) => e.id), isNot(contains('dev')));
      expect(environments.first.variables['api_key']!.value, isEmpty);
      expect(environments.first.variables['base_url']!.value, 'https://dev.api.test');
      expect(collections.endpoints.map((e) => e.name), ['List items', 'Log in', 'My profile', 'Always fails', 'Server error']);
      expect(collections.endpoints.map((e) => e.id), isNot(contains('e-items')));
      final steps = (await copy.readFlows()).single.steps.map((s) => s.endpointId).toList();
      expect(steps, [
        collections.endpoints[1].id,
        collections.endpoints[2].id,
        collections.endpoints[0].id,
      ]);
      expect(await copy.readHostNotes(), {'AUTH_HOST': 'Identity service'});
      expect(await copy.readActiveEnvironmentId(), isNull);
      expect(await copy.readAllHistory(), isEmpty);
    });

    journeyTest('requests in the copy work once an environment is chosen', (tester) async {
      final app = await demoWithSecretsAndNotes(tester);
      await app.exportActiveWorkspace();
      await app.importWorkspaceFile(app.files.savedText!);
      final dev = (await (await app.activeStore()).readEnvironments()).first;

      await app.selectEnvironment(dev.id);
      await app.expandFolder((await (await app.activeStore()).readCollections()).groups.single.id);
      await tester.tap(find.text('List items'));
      await app.settle();
      await app.send();

      expect(app.backend.lastCall.url, 'https://dev.api.test/items');
      expect(find.descendant(of: app.responsePane, matching: find.text('200')), findsOneWidget);
    });

    journeyTest('the original and the copy do not affect each other', (tester) async {
      final app = await demoWithSecretsAndNotes(tester);
      await app.exportActiveWorkspace();
      await app.importWorkspaceFile(app.files.savedText!);

      await app.createFolder('Only in the copy');
      await app.switchProject('Default');

      expect(find.text('Only in the copy'), findsNothing);
      expect(find.text('Demo API'), findsOneWidget);

      await app.switchProject('Default (2)');
      await app.deleteActiveProject();

      expect(app.projectLabel('Default'), findsOneWidget);
      expect(find.text('Demo API'), findsOneWidget);
      expect((await app.store.readEnvironments()).first.variables['api_key']!.value, 'S3CR3T-DEV-KEY');
    });

    journeyTest('the same file can be imported again and gets its own name', (tester) async {
      final app = await demoWithSecretsAndNotes(tester);
      await app.exportActiveWorkspace();
      final text = app.files.savedText!;

      await app.importWorkspaceFile(text);
      await app.importWorkspaceFile(text);

      expect((await app.projects.projects()).map((p) => p.name), ['Default', 'Default (2)', 'Default (3)']);
    });

    journeyTest('a file that is not a workspace is explained and nothing changes', (tester) async {
      final app = await harness().launchApp(tester);

      await app.importWorkspaceFile('{"groups": [], "endpoints": []}');

      expect(find.byKey(const Key('import-error-dialog')), findsOneWidget);
      expect(find.text('That file is not an API Flow Studio workspace.'), findsOneWidget);
      await app.tapKey(const Key('import-error-ok-button'));
      expect((await app.projects.projects()).map((p) => p.name), ['Default']);
      expect(app.projectLabel('Default'), findsOneWidget);
      expect(find.text('Demo API'), findsOneWidget);
    });

    journeyTest('a damaged file and a file from a newer version are refused too', (tester) async {
      final app = await harness().launchApp(tester);

      await app.importWorkspaceFile('not json at all');
      expect(find.text('That file is not valid JSON.'), findsOneWidget);
      await app.tapKey(const Key('import-error-ok-button'));

      await app.importWorkspaceFile(jsonEncode({
        'format': workspaceFormat,
        'version': workspaceFormatVersion + 1,
        'project': {'name': 'future'},
      }));
      expect(find.textContaining('newer version'), findsOneWidget);
      await app.tapKey(const Key('import-error-ok-button'));

      expect((await app.projects.projects()).map((p) => p.name), ['Default']);
    });

    journeyTest('cancelling the open dialog changes nothing', (tester) async {
      final app = await harness().launchApp(tester);
      app.files.textToOpen = null;

      await app.openProjectMenu();
      await app.tapKey(const Key('import-workspace-button'));

      expect((await app.projects.projects()), hasLength(1));
      expect(find.byKey(const Key('import-error-dialog')), findsNothing);
    });

    journeyTest('an imported project is still there after a restart', (tester) async {
      final app = await demoWithSecretsAndNotes(tester);
      await app.exportActiveWorkspace();
      await app.importWorkspaceFile(app.files.savedText!);

      await app.restart();

      expect(app.projectLabel('Default (2)'), findsOneWidget);
      expect(find.text('Demo API'), findsOneWidget);
    });
  });
}
