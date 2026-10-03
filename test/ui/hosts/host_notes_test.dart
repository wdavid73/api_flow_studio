import 'package:api_flow_studio/app.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Environment env(String id, String name, Map<String, String> vars, {Set<String> secret = const {}}) => Environment(
      id: id,
      name: name,
      variables: {for (final e in vars.entries) e.key: EnvironmentVariable(value: e.value, secret: secret.contains(e.key))},
    );

void main() {
  late JsonStore store;

  Future<void> pump(WidgetTester tester, {List<Environment>? environments, Map<String, String>? notes}) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    store = JsonStore.inMemory();
    await store.writeEnvironments(environments ??
        [
          env('dev', 'Dev', {'AUTH': 'https://dev/auth'}),
          env('qa', 'QA', {'AUTH': 'https://qa/auth'}),
        ]);
    await store.writeActiveEnvironmentId('dev');
    if (notes != null) await store.writeHostNotes(notes);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonStoreProvider.overrideWithValue(store)],
        child: const ApiFlowStudioApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('hosts-button')));
    await tester.pumpAndSettle();
  }

  Future<void> closeDialog(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('hosts-close-button')));
    await tester.pumpAndSettle();
  }

  Finder note(String name) => find.byKey(Key('host-note-$name'));

  String noteText(WidgetTester tester, String name) => tester.widget<TextField>(note(name)).controller!.text;

  Future<void> addHost(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(const Key('hosts-add-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('host-name-field')), name);
    await tester.tap(find.byKey(const Key('host-name-confirm')));
    await tester.pumpAndSettle();
  }

  group('notes', () {
    testWidgets('a stored note is shown in the Note column', (tester) async {
      await pump(tester, notes: {'AUTH': 'Identity: login'});
      await tester.pump();
      await openDialog(tester);

      expect(find.text('NOTE'), findsOneWidget);
      expect(noteText(tester, 'AUTH'), 'Identity: login');
    });

    testWidgets('typing a note saves it by base name', (tester) async {
      await pump(tester);
      await openDialog(tester);

      await tester.enterText(note('AUTH'), 'Identity and sessions');
      await tester.pump();

      expect(await store.readHostNotes(), {'AUTH': 'Identity and sessions'});
    });

    testWidgets('the note is still there after closing and reopening the dialog', (tester) async {
      await pump(tester);
      await openDialog(tester);
      await tester.enterText(note('AUTH'), 'Kept');
      await tester.pump();

      await closeDialog(tester);
      await openDialog(tester);

      expect(noteText(tester, 'AUTH'), 'Kept');
    });

    testWidgets('clearing a note removes it from the file', (tester) async {
      await pump(tester, notes: {'AUTH': 'old note'});
      await tester.pump();
      await openDialog(tester);

      await tester.enterText(note('AUTH'), '');
      await tester.pump();

      expect(await store.readHostNotes(), isEmpty);
    });

    testWidgets('a note belongs to the base, not to an environment', (tester) async {
      await pump(tester);
      await openDialog(tester);

      await tester.enterText(note('AUTH'), 'Shared');
      await tester.pump();

      expect(find.byKey(const Key('host-note-AUTH')), findsOneWidget);
      expect((await store.readEnvironments()).every((e) => !e.variables.containsKey('AUTH_NOTE')), isTrue);
    });

    testWidgets('typing a note does not touch the environments', (tester) async {
      await pump(tester);
      final before = await store.readEnvironments();
      await openDialog(tester);

      await tester.enterText(note('AUTH'), 'Just a note');
      await tester.pump();

      expect(await store.readEnvironments(), before);
    });
  });

  group('Add host', () {
    testWidgets('creates an empty row with every cell missing', (tester) async {
      await pump(tester);
      await openDialog(tester);

      await addHost(tester, 'NEW_HOST');

      expect(find.byKey(const Key('host-row-NEW_HOST')), findsOneWidget);
      for (final id in ['dev', 'qa']) {
        expect(
          find.descendant(of: find.byKey(Key('host-cell-NEW_HOST-$id')), matching: find.text('missing')),
          findsOneWidget,
        );
      }
    });

    testWidgets('typing a URL into a cell turns it into a real, persisted base', (tester) async {
      await pump(tester);
      await openDialog(tester);
      await addHost(tester, 'NEW_HOST');

      await tester.enterText(find.byKey(const Key('host-field-NEW_HOST-dev')), 'https://dev/new');
      await tester.pump();
      await closeDialog(tester);
      await openDialog(tester);

      expect(find.byKey(const Key('host-row-NEW_HOST')), findsOneWidget);
      expect((await store.readEnvironments()).firstWhere((e) => e.id == 'dev').variables['NEW_HOST']!.value, 'https://dev/new');
    });

    testWidgets('a host that never got a value disappears when the dialog is closed', (tester) async {
      await pump(tester);
      await openDialog(tester);
      await addHost(tester, 'NEW_HOST');

      await closeDialog(tester);
      await openDialog(tester);

      expect(find.byKey(const Key('host-row-NEW_HOST')), findsNothing);
    });

    testWidgets('an empty name is rejected with a message', (tester) async {
      await pump(tester);
      await openDialog(tester);

      await addHost(tester, '   ');

      expect(find.text('Enter a name.'), findsOneWidget);
      expect(find.byKey(const Key('host-row-')), findsNothing);
    });

    testWidgets('a name that already exists is rejected', (tester) async {
      await pump(tester);
      await openDialog(tester);

      await addHost(tester, 'AUTH');

      expect(find.text('That host already exists.'), findsOneWidget);
    });

    testWidgets('a name that cannot be used as a {{variable}} is rejected', (tester) async {
      await pump(tester);
      await openDialog(tester);

      await addHost(tester, 'my host');

      expect(find.text('Use letters, digits and underscores only.'), findsOneWidget);
      expect(find.byKey(const Key('host-row-my host')), findsNothing);
    });

    testWidgets('a name used by a secret variable is rejected', (tester) async {
      await pump(tester, environments: [
        env('dev', 'Dev', {'AUTH': 'https://dev/auth', 'KEY': 'https://secret'}, secret: {'KEY'}),
      ]);
      await openDialog(tester);

      await addHost(tester, 'KEY');

      expect(find.text('A secret variable already uses that name.'), findsOneWidget);
    });

    testWidgets('Cancel adds nothing', (tester) async {
      await pump(tester);
      await openDialog(tester);
      await tester.tap(find.byKey(const Key('hosts-add-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('host-name-field')), 'NEVER');

      await tester.tap(find.byKey(const Key('host-name-cancel')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('host-row-NEVER')), findsNothing);
    });
  });
}
