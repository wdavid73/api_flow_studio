import 'dart:io';

import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/active_environment_strip.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/request_builder/request_bar.dart';
import 'package:api_flow_studio/ui/request_builder/send_provider.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Real dart:io I/O (JsonStore) needs tester.runAsync(); see the note in
// tasks/plan.md.

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

void main() {
  setUpAll(() => registerFallbackValue(FakeEndpoint()));

  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
  }

  Future<({MockRequestExecutor executor, JsonStore store})> pumpRequestBar(
    WidgetTester tester, {
    required List<Environment> environments,
    String? activeEnvironmentId,
  }) async {
    final tempDir = await Directory.systemTemp.createTemp('variable_interp_test_');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final store = JsonStore(directory: tempDir);
    await store.writeEnvironments(environments);
    if (activeEnvironmentId != null) {
      await store.writeActiveEnvironmentId(activeEnvironmentId);
    }
    final executor = MockRequestExecutor();
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 200));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsonStoreProvider.overrideWithValue(store),
          requestExecutorProvider.overrideWithValue(executor),
        ],
        child: const MaterialApp(home: Scaffold(body: RequestBar())),
      ),
    );
    await settle(tester);
    return (executor: executor, store: store);
  }

  testWidgets('a request URL using {{base_url}} sends against the active environment\'s value',
      (tester) async {
    await tester.runAsync(() async {
      final env = Environment(
        id: 'env-dev',
        name: 'Development',
        variables: const {'base_url': EnvironmentVariable(value: 'https://api.dev.example.com')},
      );
      final ctx = await pumpRequestBar(tester, environments: [env], activeEnvironmentId: env.id);

      await tester.enterText(find.byKey(const Key('request-url-field')), '{{base_url}}/users');
      await settle(tester);
      await tester.tap(find.text('Send'));
      await settle(tester);

      final captured = verify(
        () => ctx.executor.execute(any(), variables: captureAny(named: 'variables')),
      ).captured;
      expect(captured.single, {'base_url': 'https://api.dev.example.com'});
    });
  });

  testWidgets('switching the active environment resolves the same draft against the new values',
      (tester) async {
    await tester.runAsync(() async {
      final dev = Environment(
        id: 'env-dev',
        name: 'Development',
        variables: const {'base_url': EnvironmentVariable(value: 'https://api.dev.example.com')},
      );
      final qa = Environment(
        id: 'env-qa',
        name: 'QA',
        variables: const {'base_url': EnvironmentVariable(value: 'https://api.qa.example.com')},
      );
      final ctx = await pumpRequestBar(
        tester,
        environments: [dev, qa],
        activeEnvironmentId: dev.id,
      );

      await tester.enterText(find.byKey(const Key('request-url-field')), '{{base_url}}/users');
      await settle(tester);
      await tester.tap(find.text('Send'));
      await settle(tester);

      // Switch to QA (the switcher itself lives in AppShell's nav bar, not
      // under RequestBar -- drive it via the provider directly, same
      // effect as picking "QA" from the real dropdown) and resend.
      final container = ProviderScope.containerOf(tester.element(find.byType(RequestBar)));
      await container.read(environmentsProvider.notifier).setActive(qa.id);
      await settle(tester);
      await tester.tap(find.text('Send'));
      await settle(tester);

      final calls = verify(
        () => ctx.executor.execute(any(), variables: captureAny(named: 'variables')),
      ).captured;
      expect(calls[0], {'base_url': 'https://api.dev.example.com'});
      expect(calls[1], {'base_url': 'https://api.qa.example.com'});
    });
  });

  testWidgets('an undefined variable is sent literally instead of crashing', (tester) async {
    await tester.runAsync(() async {
      final ctx = await pumpRequestBar(tester, environments: const []);

      await tester.enterText(find.byKey(const Key('request-url-field')), '{{nope}}/users');
      await settle(tester);
      await tester.tap(find.text('Send'));
      await settle(tester);

      final endpoint = verify(
        () => ctx.executor.execute(captureAny(), variables: any(named: 'variables')),
      ).captured.single as Endpoint;
      expect(endpoint.url, '{{nope}}/users');
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('the environment-health strip colors match the active environment', (tester) async {
    await tester.runAsync(() async {
      final dev = Environment(id: 'env-dev', name: 'Development');
      final qa = Environment(id: 'env-qa', name: 'QA');

      final tempDir = await Directory.systemTemp.createTemp('strip_test_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final store = JsonStore(directory: tempDir);
      await store.writeEnvironments([dev, qa]);
      await store.writeActiveEnvironmentId(qa.id);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [jsonStoreProvider.overrideWithValue(store)],
          child: const MaterialApp(home: Scaffold(body: ActiveEnvironmentStrip())),
        ),
      );
      await settle(tester);

      final strip = tester.widget<Container>(find.byKey(const Key('active-environment-strip')));
      final decoration = strip.decoration as BoxDecoration?;
      expect(decoration?.color ?? strip.color, AppColors.environmentDotColor(1));
    });
  });
}
