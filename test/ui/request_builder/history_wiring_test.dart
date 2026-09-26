import 'dart:io';

import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart' show jsonStoreProvider;
import 'package:api_flow_studio/ui/request_builder/request_bar.dart';
import 'package:api_flow_studio/ui/request_builder/request_draft_provider.dart';
import 'package:api_flow_studio/ui/request_builder/send_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Real dart:io I/O (JsonStore) needs tester.runAsync(); see tasks/plan.md.

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

void main() {
  setUpAll(() => registerFallbackValue(FakeEndpoint()));

  Future<void> settle(WidgetTester tester) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('sending a saved endpoint 3 times appends 3 history entries', (tester) async {
    await tester.runAsync(() async {
      final tempDir = await Directory.systemTemp.createTemp('history_wiring_test_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final store = JsonStore(directory: tempDir);
      const savedEndpoint = Endpoint(
        id: 'e-1',
        groupId: 'g-1',
        name: 'Get user',
        method: 'GET',
        url: 'https://api.dev/users/1',
      );
      final executor = MockRequestExecutor();
      when(() => executor.execute(any(), variables: any(named: 'variables')))
          .thenAnswer((_) async => const ExecutedResponse(status: 200, body: '{"ok":true}'));

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

      final container = ProviderScope.containerOf(tester.element(find.byType(RequestBar)));
      container.read(requestDraftProvider.notifier).loadEndpoint(savedEndpoint);
      await settle(tester);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Send'));
        await settle(tester);
      }

      final history = await store.readHistory('e-1');
      expect(history, hasLength(3));
      expect(history.every((h) => h.status == 200), isTrue);
    });
  });

  testWidgets('sending an unsaved draft does not error and does not write history',
      (tester) async {
    await tester.runAsync(() async {
      final tempDir = await Directory.systemTemp.createTemp('history_wiring_test_');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final store = JsonStore(directory: tempDir);
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

      await tester.enterText(find.byKey(const Key('request-url-field')), 'https://api.dev/x');
      await settle(tester);
      await tester.tap(find.text('Send'));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(await store.readHistory(draftEndpointId), isEmpty);
    });
  });
}
