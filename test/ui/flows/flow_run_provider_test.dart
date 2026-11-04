import 'dart:async';

import 'package:api_flow_studio/engine/flows/flow_step_result.dart';
import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/flows/flow_run_provider.dart';
import 'package:api_flow_studio/ui/projects/projects_provider.dart';
import 'package:api_flow_studio/ui/request_builder/request_executor_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockRequestExecutor extends Mock implements RequestExecutor {}

class FakeEndpoint extends Fake implements Endpoint {}

const ok = FlowStepResult(status: FlowStepStatus.success);
const failed = FlowStepResult(status: FlowStepStatus.failure);
const skipped = FlowStepResult(status: FlowStepStatus.skipped);

void main() {
  setUpAll(() => registerFallbackValue(FakeEndpoint()));

  const register = Endpoint(id: 'e-0', groupId: 'g', name: 'Register', method: 'POST', url: '{{base_url}}/register');
  const me = Endpoint(id: 'e-1', groupId: 'g', name: 'Me', method: 'GET', url: '{{base_url}}/users/{{user_id}}');
  const home = Endpoint(id: 'e-2', groupId: 'g', name: 'Home', method: 'GET', url: '{{base_url}}/home');
  final endpoints = {register.id: register, me.id: me, home.id: home};
  const flow = Flow(
    id: 'f',
    name: 'Sign up',
    steps: [
      FlowStep(endpointId: 'e-0', extract: {'user_id': 'response.body.id'}),
      FlowStep(endpointId: 'e-1'),
      FlowStep(endpointId: 'e-2'),
    ],
  );

  late MockRequestExecutor executor;
  late JsonStore store;
  late StateController<String> project;
  late ProviderContainer container;

  setUp(() async {
    executor = MockRequestExecutor();
    store = JsonStore.inMemory();
    await store.writeEnvironments(const [
      Environment(id: 'dev', name: 'Dev', variables: {'base_url': EnvironmentVariable(value: 'https://api.dev')}),
    ]);
    await store.writeActiveEnvironmentId('dev');
    final projectId = StateProvider<String>((ref) => 'p-1');
    container = ProviderContainer(overrides: [
      jsonStoreProvider.overrideWithValue(store),
      requestExecutorProvider.overrideWithValue(executor),
      activeProjectIdProvider.overrideWith((ref) => ref.watch(projectId)),
    ]);
    project = container.read(projectId.notifier);
    addTearDown(container.dispose);
    when(() => executor.execute(any(), variables: any(named: 'variables'))).thenAnswer((invocation) async {
      final endpoint = invocation.positionalArguments.first as Endpoint;
      return ExecutedResponse(status: 200, body: {'id': 'u-${endpoint.id}'});
    });
  });

  FlowRunNotifier notifier() => container.read(flowRunProvider('f').notifier);
  FlowRunState state() => container.read(flowRunProvider('f'));

  test('firstPendingStep', () {
    expect(firstPendingStep([ok, ok, null], 2), 2);
    expect(firstPendingStep([ok, failed, ok], 2), 1);
    expect(firstPendingStep([ok, skipped], 1), 1);
    expect(firstPendingStep([ok, ok, ok], 1), 1);
    expect(firstPendingStep(const [], 1), 0);
  });

  test('runAll fills every result and focuses the first failure', () async {
    when(() => executor.execute(me, variables: any(named: 'variables')))
        .thenAnswer((_) async => const ExecutedResponse(error: 'boom'));

    await notifier().runAll(flow, endpoints);

    expect(state().results.map((r) => r?.status), [
      FlowStepStatus.success,
      FlowStepStatus.failure,
      FlowStepStatus.skipped,
    ]);
    expect(state().focusIndex, 1);
    expect(state().running, isFalse);
    expect(state().resultAt[0], isNotNull);
  });

  test('runAll focuses the last step that ran when nothing failed', () async {
    await notifier().runAll(flow, endpoints);

    expect(state().focusIndex, 2);
  });

  test('runUntil only sends the pending steps up to the index and clears later results', () async {
    await notifier().runAll(flow, endpoints);
    clearInteractions(executor);

    await notifier().runUntil(flow, endpoints, 1);

    verify(() => executor.execute(me, variables: any(named: 'variables'))).called(1);
    verifyNever(() => executor.execute(register, variables: any(named: 'variables')));
    expect(state().results[1]?.status, FlowStepStatus.success);
    expect(state().results[2], isNull);
  });

  test('runUntil starts from the first step that has not succeeded', () async {
    await notifier().runUntil(flow, endpoints, 1);

    verify(() => executor.execute(register, variables: any(named: 'variables'))).called(1);
    verify(() => executor.execute(me, variables: any(named: 'variables'))).called(1);
    verifyNever(() => executor.execute(home, variables: any(named: 'variables')));
  });

  test('runUntil seeds the pool with what earlier steps extracted', () async {
    await notifier().runUntil(flow, endpoints, 0);
    await notifier().runUntil(flow, endpoints, 1);

    final variables = verify(() => executor.execute(me, variables: captureAny(named: 'variables'))).captured.single
        as Map<String, String>;
    expect(variables['user_id'], 'u-e-0');
    expect(variables['base_url'], 'https://api.dev');
  });

  test('runUntil re-sends an earlier step whose extract changed since it ran', () async {
    final unconnected = flow.copyWith(steps: [const FlowStep(endpointId: 'e-0'), ...flow.steps.skip(1)]);
    await notifier().runUntil(unconnected, endpoints, 0);

    // The user connects register's id to {{user_id}} after seeing the response.
    await notifier().runUntil(flow, endpoints, 1);

    verify(() => executor.execute(register, variables: any(named: 'variables'))).called(2);
    final variables = verify(() => executor.execute(me, variables: captureAny(named: 'variables'))).captured.single
        as Map<String, String>;
    expect(variables['user_id'], 'u-e-0');
  });

  test('rerunFrom first runs the earlier steps that never ran', () async {
    await notifier().runUntil(flow, endpoints, 0);
    clearInteractions(executor);

    await notifier().rerunFrom(flow, endpoints, 2);

    verifyNever(() => executor.execute(register, variables: any(named: 'variables')));
    verify(() => executor.execute(me, variables: any(named: 'variables'))).called(1);
    verify(() => executor.execute(home, variables: any(named: 'variables'))).called(1);
  });

  test('rerunFrom re-sends an earlier step whose extract changed since it ran', () async {
    final unconnected = flow.copyWith(steps: [const FlowStep(endpointId: 'e-0'), ...flow.steps.skip(1)]);
    await notifier().runAll(unconnected, endpoints);
    clearInteractions(executor);

    await notifier().rerunFrom(flow, endpoints, 1);

    verify(() => executor.execute(register, variables: any(named: 'variables'))).called(1);
    final variables = verify(() => executor.execute(me, variables: captureAny(named: 'variables'))).captured.single
        as Map<String, String>;
    expect(variables['user_id'], 'u-e-0');
  });

  test('rerunFrom re-sends from that step to the end', () async {
    await notifier().runAll(flow, endpoints);
    clearInteractions(executor);

    await notifier().rerunFrom(flow, endpoints, 1);

    verifyNever(() => executor.execute(register, variables: any(named: 'variables')));
    verify(() => executor.execute(me, variables: any(named: 'variables'))).called(1);
    verify(() => executor.execute(home, variables: any(named: 'variables'))).called(1);
  });

  test('a second run is ignored while one is in flight', () async {
    final gate = Completer<ExecutedResponse>();
    when(() => executor.execute(register, variables: any(named: 'variables'))).thenAnswer((_) => gate.future);

    final first = notifier().runAll(flow, endpoints);
    await Future<void>.delayed(Duration.zero);
    expect(await notifier().rerunFrom(flow, endpoints, 0), isNull);
    expect(await notifier().runAll(flow, endpoints), isNull);
    expect(state().running, isTrue);

    gate.complete(const ExecutedResponse(status: 200, body: {'id': 'u-e-0'}));
    await first;

    verify(() => executor.execute(register, variables: any(named: 'variables'))).called(1);
    expect(state().running, isFalse);
    expect(state().results.map((r) => r?.status), everyElement(FlowStepStatus.success));
  });

  test('requestUrlFor resolves the url with the variables entering the step', () async {
    await notifier().runUntil(flow, endpoints, 1);

    expect(notifier().requestUrlFor(1, me), 'https://api.dev/users/u-e-0');
    expect(notifier().requestUrlFor(2, home), isNull);
  });

  test('a canvas run never writes history', () async {
    await notifier().runAll(flow, endpoints);

    for (final id in endpoints.keys) {
      expect(await store.readHistory(id), isEmpty, reason: id);
    }
  });

  test('clearFrom drops results from that index on', () async {
    await notifier().runAll(flow, endpoints);

    notifier().clearFrom(1);

    expect(state().results[0]?.status, FlowStepStatus.success);
    expect(state().results[1], isNull);
    expect(state().results[2], isNull);
  });

  test('switching project drops the results', () async {
    await notifier().runAll(flow, endpoints);

    project.state = 'p-2';

    expect(state().results, isEmpty);
  });

  test('a run in flight does not write into the project switched to', () async {
    final gate = Completer<ExecutedResponse>();
    when(() => executor.execute(register, variables: any(named: 'variables'))).thenAnswer((_) => gate.future);

    final running = notifier().runAll(flow, endpoints);
    await Future<void>.delayed(Duration.zero);
    project.state = 'p-2';
    expect(state().results, isEmpty); // the new project's state exists before the old run answers
    gate.complete(const ExecutedResponse(status: 200, body: {'id': 'late'}));
    await running;

    expect(state().results, isEmpty);
    expect(state().running, isFalse);
  });
}
