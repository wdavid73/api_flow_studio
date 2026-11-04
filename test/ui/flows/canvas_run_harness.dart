import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/flows/flows_screen.dart';
import 'package:api_flow_studio/ui/request_builder/request_executor_provider.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Flows screen with [flow] open on the canvas, backed by an in-memory store
/// (a `Dev` environment with `base_url = https://api.dev`, [endpoints] in one
/// folder) and [executor] for every send. Runs the flow with Run unless [run]
/// is false. Pumps with [settle] (pumpAndSettle by default).
Future<({ProviderContainer container, JsonStore store})> pumpCanvasRun(
  WidgetTester tester, {
  required Flow flow,
  required Map<String, Endpoint> endpoints,
  required RequestExecutor executor,
  ThemeData? theme,
  bool run = true,
  Future<void> Function(WidgetTester tester)? settle,
}) async {
  final pump = settle ?? (WidgetTester t) => t.pumpAndSettle();
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final store = JsonStore.inMemory();
  await store.writeEnvironments(const [
    Environment(id: 'env-1', name: 'Dev', variables: {'base_url': EnvironmentVariable(value: 'https://api.dev')}),
  ]);
  await store.writeActiveEnvironmentId('env-1');
  await store.writeCollections(groups: const [Group(id: 'g-1', name: 'API')], endpoints: endpoints.values.toList());
  await store.writeFlows([flow]);

  final container = ProviderContainer(overrides: [
    jsonStoreProvider.overrideWithValue(store),
    requestExecutorProvider.overrideWithValue(executor),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: theme, home: const Scaffold(body: FlowsScreen())),
  ));
  await pump(tester);
  container.read(selectedFlowIdProvider.notifier).state = flow.id;
  await pump(tester);
  if (run) {
    await tester.tap(find.byKey(const Key('run-flow-button')));
    await pump(tester);
  }
  return (container: container, store: store);
}

/// Selects node [index] (by its header) and opens its Run tab when it has one.
Future<void> openRunTab(WidgetTester tester, int index, {Future<void> Function(WidgetTester tester)? settle}) async {
  final pump = settle ?? (WidgetTester t) => t.pumpAndSettle();
  await tester.tapAt(tester.getTopLeft(find.byKey(ValueKey('step-node-$index'))) + const Offset(120, 30));
  await pump(tester);
  final tab = find.byKey(const Key('step-panel-tab-run'));
  if (tab.evaluate().isNotEmpty) {
    await tester.tap(tab);
    await pump(tester);
  }
}
