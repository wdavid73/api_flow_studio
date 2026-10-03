import 'package:api_flow_studio/app.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Environment env(String id, String name, Map<String, String> vars) =>
    Environment(id: id, name: name, variables: {for (final e in vars.entries) e.key: EnvironmentVariable(value: e.value)});

Endpoint endpoint(String id, String url) => Endpoint(id: id, groupId: 'g', name: id, method: 'GET', url: url);

void main() {
  Future<void> pumpAndOpen(
    WidgetTester tester,
    List<Environment> environments, {
    String? activeId,
    List<Endpoint> endpoints = const [],
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = JsonStore.inMemory();
    await store.writeEnvironments(environments);
    await store.writeActiveEnvironmentId(activeId);
    await store.writeCollections(groups: const [Group(id: 'g', name: 'API')], endpoints: endpoints);

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

  String plain(WidgetTester tester, String name) {
    final text = tester.widget<Text>(find.descendant(of: find.byKey(Key('host-warning-$name')), matching: find.byType(Text)).last);
    return text.textSpan?.toPlainText() ?? text.data ?? '';
  }

  final envs = [
    env('dev', 'Dev', {'AUTH': 'https://dev/a', 'HOST_NAME': 'https://dev/h'}),
    env('qa', 'QA', {'AUTH': 'https://qa/a'}),
    env('prod', 'Prod', {'AUTH': 'https://prod/a'}),
  ];

  testWidgets('a base missing in some environments gets a warning naming them', (tester) async {
    await pumpAndOpen(tester, envs);

    expect(
      plain(tester, 'HOST_NAME'),
      "HOST_NAME isn't defined in QA, Prod. Requests that use {{HOST_NAME}} will be sent with that text "
      'unresolved there.',
    );
    expect(find.byKey(const Key('host-warning-AUTH')), findsNothing);
  });

  testWidgets('the warning uses the warning colors', (tester) async {
    await pumpAndOpen(tester, envs);

    final box = tester.widget<Container>(find.byKey(const Key('host-warning-HOST_NAME')));

    expect((box.decoration! as BoxDecoration).color, AppColors.bannerBackground);
  });

  testWidgets('a used base missing in the active environment is first and tagged ACTIVE', (tester) async {
    await pumpAndOpen(
      tester,
      [
        env('dev', 'Dev', {'AUTH': 'https://dev/a', 'A_FIRST': 'https://dev/f', 'Z_USED': 'https://dev/z'}),
        env('qa', 'QA', {'AUTH': 'https://qa/a'}),
      ],
      activeId: 'qa',
      endpoints: [endpoint('1', '{{Z_USED}}/x')],
    );

    final used = tester.getTopLeft(find.byKey(const Key('host-warning-Z_USED'))).dy;
    final other = tester.getTopLeft(find.byKey(const Key('host-warning-A_FIRST'))).dy;
    expect(used, lessThan(other));
    expect(
      find.descendant(of: find.byKey(const Key('host-warning-Z_USED')), matching: find.byKey(const Key('host-warning-active-tag'))),
      findsOneWidget,
    );
  });

  testWidgets('an unused base missing in the active environment gets no ACTIVE tag', (tester) async {
    await pumpAndOpen(tester, envs, activeId: 'qa');

    expect(find.byKey(const Key('host-warning-active-tag')), findsNothing);
  });

  testWidgets('with nothing missing it says every host is defined everywhere', (tester) async {
    await pumpAndOpen(tester, [
      env('dev', 'Dev', {'AUTH': 'https://dev/a'}),
      env('qa', 'QA', {'AUTH': 'https://qa/a'}),
    ]);

    expect(find.byKey(const Key('hosts-all-defined')), findsOneWidget);
    expect(find.text('Every host is defined in every environment.'), findsOneWidget);
  });

  testWidgets('with no bases only the empty message shows', (tester) async {
    await pumpAndOpen(tester, [env('dev', 'Dev', {'timeout': '30'})]);

    expect(find.byKey(const Key('hosts-empty')), findsOneWidget);
    expect(find.byKey(const Key('hosts-all-defined')), findsNothing);
  });

  testWidgets('editing a cell updates the warnings live', (tester) async {
    await pumpAndOpen(tester, envs);
    expect(find.byKey(const Key('host-warning-HOST_NAME')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('host-field-HOST_NAME-qa')), 'https://qa/h');
    await tester.enterText(find.byKey(const Key('host-field-HOST_NAME-prod')), 'https://prod/h');
    await tester.pump();

    expect(find.byKey(const Key('host-warning-HOST_NAME')), findsNothing);
    expect(find.byKey(const Key('hosts-all-defined')), findsOneWidget);
  });

  testWidgets('clearing a cell raises a warning', (tester) async {
    await pumpAndOpen(tester, [
      env('dev', 'Dev', {'AUTH': 'https://dev/a'}),
      env('qa', 'QA', {'AUTH': 'https://qa/a'}),
    ]);
    expect(find.byKey(const Key('host-warning-AUTH')), findsNothing);

    await tester.enterText(find.byKey(const Key('host-field-AUTH-qa')), '');
    await tester.pump();

    expect(plain(tester, 'AUTH'), startsWith("AUTH isn't defined in QA."));
  });

  testWidgets('many bases and warnings scroll inside the dialog instead of overflowing it', (tester) async {
    await pumpAndOpen(
      tester,
      [
        env('dev', 'Dev', {for (var i = 0; i < 30; i++) 'HOST_$i': 'https://dev/$i'}),
        env('qa', 'QA', {}),
      ],
      activeId: 'dev',
    );
    tester.view.physicalSize = const Size(1400, 600);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('hosts-body-scroll')), findsOneWidget);
  });
}
