import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/flows/flow_run_provider.dart';
import 'package:api_flow_studio/ui/flows/step_response.dart';
import 'package:api_flow_studio/ui/history/history_provider.dart';
import 'package:api_flow_studio/ui/request_builder/request_executor_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

void main() {
  setUpAll(() => registerFallbackValue(FakeEndpoint()));

  const endpoint = Endpoint(id: 'e-1', groupId: 'g', name: 'Me', method: 'GET', url: '/me');
  const flow = Flow(id: 'f', name: 'F', steps: [FlowStep(endpointId: 'e-1')]);
  const key = (flowId: 'f', index: 0, endpointId: 'e-1');

  late JsonStore store;
  late MockRequestExecutor executor;
  late ProviderContainer container;

  setUp(() {
    store = JsonStore.inMemory();
    executor = MockRequestExecutor();
    container = ProviderContainer(overrides: [
      jsonStoreProvider.overrideWithValue(store),
      requestExecutorProvider.overrideWithValue(executor),
    ]);
    addTearDown(container.dispose);
  });

  HistoryEntry entry(String id, DateTime at, {String? body, bool truncated = false}) => HistoryEntry(
        id: id,
        endpointId: 'e-1',
        timestamp: at,
        status: body == null ? null : 200,
        body: body,
        truncated: truncated,
        error: body == null ? 'timeout' : null,
      );

  Future<StepResponse?> read() async {
    container.listen(stepResponseProvider(key), (_, _) {});
    await container.read(historyProvider('e-1').future);
    return container.read(stepResponseProvider(key)).requireValue;
  }

  test('prefers the run result over history', () async {
    await store.appendHistoryEntry('e-1', entry('h', DateTime(2026, 1, 1), body: '{"from": "history"}'));
    when(() => executor.execute(any(), variables: any(named: 'variables'))).thenAnswer(
      (_) async => const ExecutedResponse(status: 201, headers: {'x': '1'}, body: {'from': 'run'}),
    );
    await container.read(flowRunProvider('f').notifier).runAll(flow, {endpoint.id: endpoint});

    final response = await read();

    expect(response!.source, StepResponseSource.run);
    expect(response.body, {'from': 'run'});
    expect(response.status, 201);
    expect(response.headers, {'x': '1'});
    expect(response.isJson, isTrue);
    expect(response.at, isNotNull);
  });

  test('falls back to the newest history entry with a body, decoding JSON', () async {
    await store.appendHistoryEntry('e-1', entry('a', DateTime(2026, 1, 1), body: '{"v": 1}'));
    await store.appendHistoryEntry('e-1', entry('b', DateTime(2026, 1, 2), body: '{"v": 2}'));
    await store.appendHistoryEntry('e-1', entry('c', DateTime(2026, 1, 3)));

    final response = await read();

    expect(response!.source, StepResponseSource.history);
    expect(response.body, {'v': 2});
    expect(response.isJson, isTrue);
    expect(response.at, DateTime(2026, 1, 2));
  });

  test('a truncated history body is not decoded', () async {
    await store.appendHistoryEntry('e-1', entry('a', DateTime(2026, 1, 1), body: '{"v": [1, 2', truncated: true));

    final response = await read();

    expect(response!.isJson, isFalse);
    expect(response.truncated, isTrue);
  });

  test('a non-JSON history body is kept as text', () async {
    await store.appendHistoryEntry('e-1', entry('a', DateTime(2026, 1, 1), body: '<html>oops</html>'));

    final response = await read();

    expect(response!.isJson, isFalse);
    expect(response.truncated, isFalse);
    expect(response.body, '<html>oops</html>');
  });

  test('no run and no history gives null', () async {
    expect(await read(), isNull);
  });
}
