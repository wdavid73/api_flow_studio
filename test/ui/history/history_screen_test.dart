import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/history/history_screen.dart';
import 'package:api_flow_studio/ui/request_builder/request_draft_provider.dart';
import 'package:api_flow_studio/ui/request_builder/send_provider.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:api_flow_studio/ui/theme/widgets/method_badge.dart';
import 'package:api_flow_studio/ui/theme/widgets/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

const _group = Group(id: 'g-1', name: 'Users');
const _getUser = Endpoint(
  id: 'e-get',
  groupId: 'g-1',
  name: 'Get user',
  method: 'GET',
  url: 'https://api.test/users/1',
);
const _createUser = Endpoint(
  id: 'e-create',
  groupId: 'g-1',
  name: 'Create user',
  method: 'POST',
  url: 'https://api.test/users',
);

HistoryEntry entry(String id, String endpointId, DateTime at, {int? status = 200, int ms = 42, String? error}) =>
    HistoryEntry(id: id, endpointId: endpointId, timestamp: at, status: status, elapsedMs: ms, error: error);

void main() {
  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Endpoint> endpoints = const [_getUser, _createUser],
    List<HistoryEntry> history = const [],
  }) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = JsonStore.inMemory();
    await store.writeCollections(groups: const [_group], endpoints: endpoints);
    for (final h in history) {
      await store.appendHistoryEntry(h.endpointId, h);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [jsonStoreProvider.overrideWithValue(store)],
        child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: HistoryScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the kicker, title and the empty message when nothing was sent', (tester) async {
    await pumpScreen(tester);

    expect(find.text('HISTORY'), findsOneWidget);
    expect(find.text('Request history'), findsOneWidget);
    expect(find.byKey(const Key('history-screen-empty')), findsOneWidget);
    expect(find.text('No history yet \u2014 send a saved request.'), findsOneWidget);
  });

  testWidgets('a row shows method, name, url, status, elapsed time and the hour', (tester) async {
    final now = DateTime.now();
    await pumpScreen(tester, history: [entry('h1', 'e-get', now, status: 200, ms: 42)]);

    final row = find.byKey(const ValueKey('history-entry-h1'));
    expect(find.descendant(of: row, matching: find.byType(MethodBadge)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('GET')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('Get user')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('https://api.test/users/1')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.byType(StatusBadge)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('200')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('42 ms')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.textContaining(RegExp(r'^\d\d:\d\d$'))), findsOneWidget);
  });

  testWidgets('a failed send shows Error in the error color instead of a status', (tester) async {
    await pumpScreen(
      tester,
      history: [entry('h1', 'e-get', DateTime.now(), status: null, error: 'Connection refused')],
    );

    final row = find.byKey(const ValueKey('history-entry-h1'));
    expect(find.descendant(of: row, matching: find.byType(StatusBadge)), findsNothing);
    final text = tester.widget<Text>(find.descendant(of: row, matching: find.text('Error')));
    expect(text.style?.color, AppColors.error);
  });

  testWidgets('entries are listed newest first across requests', (tester) async {
    final now = DateTime.now();
    await pumpScreen(tester, history: [
      entry('old', 'e-get', now.subtract(const Duration(minutes: 5))),
      entry('new', 'e-create', now),
      entry('mid', 'e-get', now.subtract(const Duration(minutes: 2))),
    ]);

    double top(String id) => tester.getTopLeft(find.byKey(ValueKey('history-entry-$id'))).dy;

    expect(top('new'), lessThan(top('mid')));
    expect(top('mid'), lessThan(top('old')));
  });

  testWidgets('entries are grouped under TODAY, YESTERDAY and an ISO date', (tester) async {
    final now = DateTime.now();
    final noon = DateTime(now.year, now.month, now.day, 12);
    final threeDaysAgo = noon.subtract(const Duration(days: 3));
    await pumpScreen(tester, history: [
      entry('today', 'e-get', now),
      entry('yesterday', 'e-get', noon.subtract(const Duration(days: 1))),
      entry('older', 'e-get', threeDaysAgo),
    ]);

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('YESTERDAY'), findsOneWidget);
    final iso = '${threeDaysAgo.year}-${threeDaysAgo.month.toString().padLeft(2, '0')}-'
        '${threeDaysAgo.day.toString().padLeft(2, '0')}';
    expect(find.text(iso), findsOneWidget);
  });

  testWidgets('an entry whose request was deleted still shows, as Deleted request', (tester) async {
    await pumpScreen(
      tester,
      endpoints: const [_getUser],
      history: [entry('h1', 'e-gone', DateTime.now())],
    );

    final row = find.byKey(const ValueKey('history-entry-h1'));
    expect(find.descendant(of: row, matching: find.text('Deleted request')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.byType(MethodBadge)), findsNothing);
  });

  testWidgets('a send recorded while the screen is open shows up without reloading', (tester) async {
    registerFallbackValue(FakeEndpoint());
    final executor = MockRequestExecutor();
    when(() => executor.execute(any(), variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(status: 201, body: '{}', elapsedMs: 9));
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = JsonStore.inMemory();
    await store.writeCollections(groups: const [_group], endpoints: const [_getUser]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          jsonStoreProvider.overrideWithValue(store),
          requestExecutorProvider.overrideWithValue(executor),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: HistoryScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('history-screen-empty')), findsOneWidget);

    final container = ProviderScope.containerOf(tester.element(find.byType(HistoryScreen)));
    container.read(requestDraftProvider.notifier).loadEndpoint(_getUser);
    await tester.runAsync(() => container.read(sendStateProvider.notifier).send());
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('history-screen-empty')), findsNothing);
    expect(find.text('201'), findsOneWidget);
  });
}
