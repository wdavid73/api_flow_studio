import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart' show jsonStoreProvider;
import 'package:api_flow_studio/ui/flows/flows_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late JsonStore store;
  late ProviderContainer container;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('flows_provider_test_');
    store = JsonStore(directory: tempDir);
    container = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('createFlow persists a new empty flow', () async {
    final notifier = container.read(flowsProvider.notifier);
    await notifier.createFlow('User Registration Flow');

    final flows = await container.read(flowsProvider.future);
    expect(flows.single.name, 'User Registration Flow');
    expect(flows.single.steps, isEmpty);
    expect((await store.readFlows()).single.name, 'User Registration Flow');
  });

  test('a flow with 3 steps referencing existing endpoint ids round-trips via disk', () async {
    final notifier = container.read(flowsProvider.notifier);
    final flow = await notifier.createFlow('Flow');
    await notifier.addStep(flow.id, const FlowStep(endpointId: 'e-check'));
    await notifier.addStep(flow.id, const FlowStep(endpointId: 'e-otp'));
    await notifier.addStep(flow.id, const FlowStep(endpointId: 'e-create'));

    final persisted = (await store.readFlows()).single;
    expect(persisted.steps.map((s) => s.endpointId), ['e-check', 'e-otp', 'e-create']);
  });

  test('reorderStep persists the new step order', () async {
    final notifier = container.read(flowsProvider.notifier);
    final flow = await notifier.createFlow('Flow');
    await notifier.addStep(flow.id, const FlowStep(endpointId: 'a'));
    await notifier.addStep(flow.id, const FlowStep(endpointId: 'b'));
    await notifier.addStep(flow.id, const FlowStep(endpointId: 'c'));

    await notifier.reorderStep(flow.id, 2, 0); // move 'c' to the front

    final steps = (await store.readFlows()).single.steps;
    expect(steps.map((s) => s.endpointId), ['c', 'a', 'b']);
  });

  test('updateStep replaces just that step, at its index', () async {
    final notifier = container.read(flowsProvider.notifier);
    final flow = await notifier.createFlow('Flow');
    await notifier.addStep(flow.id, const FlowStep(endpointId: 'a'));
    await notifier.addStep(flow.id, const FlowStep(endpointId: 'b'));

    await notifier.updateStep(
      flow.id,
      0,
      const FlowStep(endpointId: 'a', extract: {'token': 'response.body.token'}),
    );

    final steps = (await store.readFlows()).single.steps;
    expect(steps[0].extract, {'token': 'response.body.token'});
    expect(steps[1].endpointId, 'b');
  });

  test('removeStep drops just that step', () async {
    final notifier = container.read(flowsProvider.notifier);
    final flow = await notifier.createFlow('Flow');
    await notifier.addStep(flow.id, const FlowStep(endpointId: 'a'));
    await notifier.addStep(flow.id, const FlowStep(endpointId: 'b'));

    await notifier.removeStep(flow.id, 0);

    final steps = (await store.readFlows()).single.steps;
    expect(steps.map((s) => s.endpointId), ['b']);
  });

  test('renameFlow and deleteFlow persist', () async {
    final notifier = container.read(flowsProvider.notifier);
    final flow = await notifier.createFlow('Old name');

    await notifier.renameFlow(flow.id, 'New name');
    expect((await store.readFlows()).single.name, 'New name');

    await notifier.deleteFlow(flow.id);
    expect(await store.readFlows(), isEmpty);
  });
}
