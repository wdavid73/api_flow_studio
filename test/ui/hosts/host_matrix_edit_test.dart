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

  Future<void> pumpAndOpen(WidgetTester tester, List<Environment> environments) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    store = JsonStore.inMemory();
    await store.writeEnvironments(environments);
    await store.writeActiveEnvironmentId('dev');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonStoreProvider.overrideWithValue(store)],
        child: const ApiFlowStudioApp(),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('hosts-button')));
    await tester.pumpAndSettle();
  }

  Finder field(String name, String envId) => find.byKey(Key('host-field-$name-$envId'));

  Future<Environment> stored(String id) async => (await store.readEnvironments()).firstWhere((e) => e.id == id);

  final threeEnvs = [
    env('dev', 'Dev', {'AUTH': 'https://dev/auth', 'MARKET': 'https://dev/market', 'timeout': '30'}),
    env('qa', 'QA', {'AUTH': 'https://qa/auth', 'timeout': '45'}),
    env('prod', 'Prod', {'AUTH': 'https://prod/auth', 'MARKET': 'https://prod/market'}),
  ];

  testWidgets('every cell is an editable field holding its value', (tester) async {
    await pumpAndOpen(tester, threeEnvs);

    expect(tester.widget<TextField>(field('AUTH', 'qa')).controller!.text, 'https://qa/auth');
    expect(tester.widget<TextField>(field('MARKET', 'qa')).controller!.text, isEmpty);
  });

  testWidgets('typing changes exactly that variable in that environment and persists', (tester) async {
    await pumpAndOpen(tester, threeEnvs);

    await tester.enterText(field('AUTH', 'qa'), 'https://qa2/auth');
    await tester.pump();

    final qa = await stored('qa');
    expect(qa.variables['AUTH']!.value, 'https://qa2/auth');
    expect(qa.variables['timeout']!.value, '45');
    expect((await stored('dev')).variables['AUTH']!.value, 'https://dev/auth');
    expect((await stored('prod')).variables['AUTH']!.value, 'https://prod/auth');
  });

  testWidgets('clearing a cell removes the variable from that environment only', (tester) async {
    await pumpAndOpen(tester, threeEnvs);

    await tester.enterText(field('AUTH', 'dev'), '');
    await tester.pump();

    expect((await stored('dev')).variables.containsKey('AUTH'), isFalse);
    expect((await stored('dev')).variables['timeout']!.value, '30');
    expect((await stored('qa')).variables.containsKey('AUTH'), isTrue);
    expect((await stored('prod')).variables.containsKey('AUTH'), isTrue);
  });

  testWidgets('a cleared cell shows missing', (tester) async {
    await pumpAndOpen(tester, threeEnvs);

    await tester.enterText(field('AUTH', 'dev'), '');
    await tester.pump();

    expect(find.descendant(of: find.byKey(const Key('host-cell-AUTH-dev')), matching: find.text('missing')), findsOneWidget);
  });

  testWidgets('typing into an empty cell creates the variable in that environment', (tester) async {
    await pumpAndOpen(tester, threeEnvs);

    await tester.enterText(field('MARKET', 'qa'), 'https://qa/market');
    await tester.pump();

    final qa = await stored('qa');
    expect(qa.variables['MARKET']!.value, 'https://qa/market');
    expect(qa.variables['MARKET']!.secret, isFalse);
    expect(find.descendant(of: find.byKey(const Key('host-cell-MARKET-qa')), matching: find.text('missing')), findsNothing);
  });

  testWidgets('typing letter by letter never makes the row disappear', (tester) async {
    await pumpAndOpen(tester, [
      env('dev', 'Dev', {'AUTH': 'https://dev/auth'}),
    ]);

    for (final partial in ['', 'h', 'ht', 'htt', 'http', 'https://x']) {
      await tester.enterText(field('AUTH', 'dev'), partial);
      await tester.pump();

      expect(find.byKey(const Key('host-row-AUTH')), findsOneWidget, reason: '"$partial"');
    }
    expect((await stored('dev')).variables['AUTH']!.value, 'https://x');
  });

  testWidgets('a value that is no longer a URL drops its row when the dialog is reopened', (tester) async {
    await pumpAndOpen(tester, [
      env('dev', 'Dev', {'AUTH': 'https://dev/auth'}),
    ]);

    await tester.enterText(field('AUTH', 'dev'), 'not a url anymore');
    await tester.pump();
    expect(find.byKey(const Key('host-row-AUTH')), findsOneWidget);

    await tester.tap(find.byKey(const Key('hosts-close-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hosts-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('host-row-AUTH')), findsNothing);
    expect((await stored('dev')).variables['AUTH']!.value, 'not a url anymore');
  });

  testWidgets('editing keeps the secret flag of other variables and never lists secrets', (tester) async {
    await pumpAndOpen(tester, [
      env('dev', 'Dev', {'AUTH': 'https://dev/auth', 'KEY': 'https://secret'}, secret: {'KEY'}),
    ]);

    expect(field('KEY', 'dev'), findsNothing);

    await tester.enterText(field('AUTH', 'dev'), 'https://dev/auth2');
    await tester.pump();

    final dev = await stored('dev');
    expect(dev.variables['KEY']!.secret, isTrue);
    expect(dev.variables['KEY']!.value, 'https://secret');
  });

  testWidgets('the edited environment changes in the rest of the app too', (tester) async {
    await pumpAndOpen(tester, threeEnvs);

    await tester.enterText(field('AUTH', 'dev'), 'https://changed/auth');
    await tester.pump();

    final container = ProviderScope.containerOf(tester.element(find.byKey(const Key('hosts-dialog'))));
    final dev = container.read(environmentsProvider).value!.environments.firstWhere((e) => e.id == 'dev');
    expect(dev.variables['AUTH']!.value, 'https://changed/auth');
  });
}
