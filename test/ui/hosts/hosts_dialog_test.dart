import 'package:api_flow_studio/app.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _group = Group(id: 'g', name: 'API');

Environment env(String id, String name, Map<String, String> vars, {Set<String> secret = const {}}) => Environment(
      id: id,
      name: name,
      variables: {for (final e in vars.entries) e.key: EnvironmentVariable(value: e.value, secret: secret.contains(e.key))},
    );

Endpoint endpoint(String id, String url) => Endpoint(id: id, groupId: 'g', name: id, method: 'GET', url: url);

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    required List<Environment> environments,
    String? activeId = 'dev',
    List<Endpoint> endpoints = const [],
    Size size = const Size(1600, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = JsonStore.inMemory();
    await store.writeEnvironments(environments);
    await store.writeActiveEnvironmentId(activeId);
    await store.writeCollections(groups: const [_group], endpoints: endpoints);

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

  final threeEnvs = [
    env('dev', 'Dev', {'AUTH': 'https://dev/auth', 'MARKET': 'https://dev/market', 'timeout': '30'}),
    env('qa', 'QA', {'AUTH': 'https://qa/auth'}),
    env('prod', 'Prod', {'AUTH': 'https://prod/auth', 'MARKET': 'https://prod/market'}),
  ];

  testWidgets('the Hosts & notes button sits in the header, left of the session button', (tester) async {
    await pumpApp(tester, environments: threeEnvs);

    expect(find.text('Hosts & notes'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('hosts-button'))).dx,
      lessThan(tester.getTopLeft(find.byKey(const Key('session-button'))).dx),
    );
  });

  testWidgets('the button opens the dialog with its title and help text; Close closes it', (tester) async {
    await pumpApp(tester, environments: threeEnvs);

    expect(find.text('Hosts by environment'), findsNothing);
    await openDialog(tester);

    expect(find.text('Hosts by environment'), findsOneWidget);
    expect(
      find.text(
        'Hosts are environment variables whose value is a URL. Edit a cell to change it in that '
        'environment; clear it to remove the variable there.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('hosts-close-button')));
    await tester.pumpAndSettle();

    expect(find.text('Hosts by environment'), findsNothing);
  });

  testWidgets('Esc closes the dialog', (tester) async {
    await pumpApp(tester, environments: threeEnvs);
    await openDialog(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Hosts by environment'), findsNothing);
  });

  testWidgets('the dialog is at most 1040px wide with a 16px radius on surfaceContainerLow', (tester) async {
    await pumpApp(tester, environments: threeEnvs);
    await openDialog(tester);

    final dialog = tester.widget<Dialog>(find.byType(Dialog));

    expect(tester.getSize(find.byKey(const Key('hosts-dialog'))).width, lessThanOrEqualTo(1040));
    expect(dialog.backgroundColor, AppColors.surfaceContainerLow);
    expect((dialog.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(16));
  });

  testWidgets('shows one row per base and one column per environment with the values', (tester) async {
    await pumpApp(tester, environments: threeEnvs);
    await openDialog(tester);

    expect(find.byKey(const Key('host-row-AUTH')), findsOneWidget);
    expect(find.byKey(const Key('host-row-MARKET')), findsOneWidget);
    expect(find.byKey(const Key('host-row-timeout')), findsNothing);
    for (final name in ['Dev', 'QA', 'Prod']) {
      expect(find.byKey(Key('host-env-header-${name.toLowerCase()}')), findsOneWidget);
    }
    expect(find.text('https://dev/auth'), findsOneWidget);
    expect(find.text('https://prod/market'), findsOneWidget);
  });

  testWidgets('a base missing in an environment shows missing in that cell', (tester) async {
    await pumpApp(tester, environments: threeEnvs);
    await openDialog(tester);

    expect(find.descendant(of: find.byKey(const Key('host-cell-MARKET-qa')), matching: find.text('missing')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('host-cell-AUTH-qa')), matching: find.text('missing')), findsNothing);
  });

  testWidgets('the active environment header has a dot and a prod one has the PROD tag', (tester) async {
    await pumpApp(tester, environments: threeEnvs, activeId: 'dev');
    await openDialog(tester);

    expect(find.byKey(const Key('host-env-active-dev')), findsOneWidget);
    expect(find.byKey(const Key('host-env-active-qa')), findsNothing);
    expect(find.byKey(const Key('host-env-prod-tag-prod')), findsOneWidget);
    expect(find.byKey(const Key('host-env-prod-tag-dev')), findsNothing);
  });

  testWidgets('each base says how many requests use it, singular for one', (tester) async {
    await pumpApp(
      tester,
      environments: threeEnvs,
      endpoints: [endpoint('1', '{{AUTH}}/login'), endpoint('2', '{{AUTH}}/logout'), endpoint('3', '{{MARKET}}/x')],
    );
    await openDialog(tester);

    expect(find.descendant(of: find.byKey(const Key('host-row-AUTH')), matching: find.text('Used by 2 requests')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('host-row-MARKET')), matching: find.text('Used by 1 request')), findsOneWidget);
  });

  testWidgets('with no bases it says how to get one', (tester) async {
    await pumpApp(tester, environments: [env('dev', 'Dev', {'timeout': '30'})]);
    await openDialog(tester);

    expect(find.byKey(const Key('hosts-empty')), findsOneWidget);
    expect(
      find.text('No hosts yet — add an environment variable whose value is a URL, or use Add host.'),
      findsOneWidget,
    );
  });

  testWidgets('secret variables are never listed', (tester) async {
    await pumpApp(tester, environments: [
      env('dev', 'Dev', {'KEY': 'https://secret-host', 'AUTH': 'https://dev/auth'}, secret: {'KEY'}),
    ]);
    await openDialog(tester);

    expect(find.byKey(const Key('host-row-KEY')), findsNothing);
    expect(find.text('https://secret-host'), findsNothing);
    expect(find.byKey(const Key('host-row-AUTH')), findsOneWidget);
  });

  testWidgets('with eight environments the table scrolls sideways without overflowing', (tester) async {
    await pumpApp(
      tester,
      environments: [for (var i = 0; i < 8; i++) env('e$i', 'Env $i', {'AUTH': 'https://e$i/auth'})],
      activeId: 'e0',
      size: const Size(1300, 900),
    );
    await openDialog(tester);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('hosts-table-scroll')), findsOneWidget);
  });

  testWidgets('works with no environments at all', (tester) async {
    await pumpApp(tester, environments: const [], activeId: null);
    await openDialog(tester);

    expect(find.byKey(const Key('hosts-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the header wraps instead of overflowing with many environments and both action buttons', (tester) async {
    await pumpApp(
      tester,
      environments: [for (var i = 0; i < 8; i++) env('e$i', 'Env $i', {'AUTH': 'https://e$i/auth'})],
      activeId: 'e0',
      size: const Size(1300, 900),
    );

    expect(tester.takeException(), isNull);
  });
}
