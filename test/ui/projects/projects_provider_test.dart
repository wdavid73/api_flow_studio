import 'dart:async';

import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/projects/project.dart';
import 'package:api_flow_studio/engine/projects/projects_repository.dart';
import 'package:api_flow_studio/engine/session/session.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/collections/collections_provider.dart';
import 'package:api_flow_studio/ui/collections/endpoint_filter.dart' show allMethods;
import 'package:api_flow_studio/ui/collections/method_filter_chips.dart';
import 'package:api_flow_studio/ui/collections/sidebar_tree.dart';
import 'package:api_flow_studio/ui/environments/environment_manager_screen.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/flows/flows_provider.dart';
import 'package:api_flow_studio/ui/flows/flows_screen.dart';
import 'package:api_flow_studio/ui/history/all_history_provider.dart';
import 'package:api_flow_studio/ui/history/history_provider.dart';
import 'package:api_flow_studio/ui/history/history_screen.dart';
import 'package:api_flow_studio/ui/hosts/host_notes_provider.dart';
import 'package:api_flow_studio/ui/projects/projects_provider.dart';
import 'package:api_flow_studio/ui/request_builder/request_draft_provider.dart';
import 'package:api_flow_studio/ui/request_builder/send_provider.dart';
import 'package:api_flow_studio/ui/session/session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers when told to, so a test can switch project while a send is in flight.
class _SlowExecutor extends RequestExecutor {
  final Completer<ExecutedResponse> reply = Completer();

  @override
  Future<ExecutedResponse> execute(Endpoint endpoint, {required Map<String, String> variables}) => reply.future;
}

void main() {
  late ProjectsRepository repo;
  late Project a;
  late Project b;
  late ProviderContainer container;

  Future<JsonStore> storeOf(Project p) => repo.storeFor(p.id);

  Future<void> seed(Project p, String tag) async {
    final store = await storeOf(p);
    await store.writeEnvironments([
      Environment(id: 'env-$tag', name: 'Env $tag', variables: {'k': EnvironmentVariable(value: tag)}),
    ]);
    await store.writeActiveEnvironmentId('env-$tag');
    await store.writeCollections(
      groups: [Group(id: 'g-$tag', name: 'Group $tag')],
      endpoints: [Endpoint(id: 'e-$tag', groupId: 'g-$tag', name: 'Request $tag', method: 'GET', url: 'https://$tag.test')],
    );
    await store.writeFlows([Flow(id: 'f-$tag', name: 'Flow $tag')]);
    await store.writeHostNotes({'host-$tag': 'Note $tag'});
    await store.appendHistoryEntry(
      'e-$tag',
      HistoryEntry(id: 'h-$tag', endpointId: 'e-$tag', timestamp: DateTime.utc(2026, 10, 1), status: 200),
    );
  }

  Future<ProviderContainer> open({List<Override> extra = const []}) async {
    final state = await ProjectsController.load(repo);
    final c = ProviderContainer(overrides: [
      projectsRepositoryProvider.overrideWithValue(repo),
      initialProjectsStateProvider.overrideWithValue(state),
      ...extra,
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    repo = ProjectsRepository.inMemory();
    a = await repo.create('a');
    b = await repo.create('b');
    await seed(a, 'a');
    await seed(b, 'b');
    container = await open();
  });

  Future<void> loadEverything() async {
    await container.read(environmentsProvider.future);
    await container.read(collectionsProvider.future);
    await container.read(flowsProvider.future);
    await container.read(hostNotesProvider.future);
    await container.read(allHistoryProvider.future);
  }

  group('what the app shows follows the active project', () {
    test('it starts on the active project and exposes the list', () async {
      final state = container.read(projectsProvider);

      expect(state.active.id, a.id);
      expect(state.projects.map((p) => p.name), ['a', 'b']);
      expect(container.read(activeProjectIdProvider), a.id);
    });

    test('switching changes environments, collections, flows, host notes and history', () async {
      await loadEverything();
      expect(container.read(environmentsProvider).value!.environments.single.name, 'Env a');

      await container.read(projectsProvider.notifier).switchTo(b.id);
      await loadEverything();

      expect(container.read(environmentsProvider).value!.environments.single.name, 'Env b');
      expect(container.read(environmentsProvider).value!.activeEnvironmentId, 'env-b');
      expect(container.read(collectionsProvider).value!.endpoints.single.id, 'e-b');
      expect(container.read(flowsProvider).value!.single.id, 'f-b');
      expect(container.read(hostNotesProvider).value, {'host-b': 'Note b'});
      expect(container.read(allHistoryProvider).value!.single.id, 'h-b');
      expect((await container.read(historyProvider('e-b').future)).single.id, 'h-b');
      expect(await container.read(historyProvider('e-a').future), isEmpty);
    });

    test('going back shows the first project again, with its edits', () async {
      await loadEverything();
      await container.read(flowsProvider.notifier).createFlow('Added in a');

      await container.read(projectsProvider.notifier).switchTo(b.id);
      await loadEverything();
      expect(container.read(flowsProvider).value!.map((f) => f.name), ['Flow b']);
      await container.read(projectsProvider.notifier).switchTo(a.id);
      await loadEverything();

      expect(container.read(flowsProvider).value!.map((f) => f.name), ['Flow a', 'Added in a']);
    });

    test('a write after switching lands in the new project only', () async {
      await container.read(projectsProvider.notifier).switchTo(b.id);
      await loadEverything();

      await container.read(flowsProvider.notifier).createFlow('Only in b');

      expect((await (await storeOf(b)).readFlows()).map((f) => f.name), ['Flow b', 'Only in b']);
      expect((await (await storeOf(a)).readFlows()).map((f) => f.name), ['Flow a']);
    });

    test('creating a project makes it the active, empty one', () async {
      final created = await container.read(projectsProvider.notifier).create('c', colorIndex: 2);
      await loadEverything();

      expect(container.read(projectsProvider).active.id, created.id);
      expect(container.read(projectsProvider).projects, hasLength(3));
      expect(container.read(environmentsProvider).value!.environments, isEmpty);
      expect(container.read(collectionsProvider).value!.endpoints, isEmpty);
    });

    test('renaming updates the list and keeps the active project', () async {
      await container.read(projectsProvider.notifier).rename(a.id, 'Renamed');

      expect(container.read(projectsProvider).active.name, 'Renamed');
      expect(container.read(projectsProvider).projects.map((p) => p.name), ['Renamed', 'b']);
    });

    test('deleting the active project moves to another and drops its data', () async {
      await container.read(projectsProvider.notifier).delete(a.id);
      await loadEverything();

      expect(container.read(projectsProvider).active.id, b.id);
      expect(container.read(projectsProvider).projects.map((p) => p.id), [b.id]);
      expect(container.read(flowsProvider).value!.single.id, 'f-b');
    });

    test('the chosen project is remembered by the repository', () async {
      await container.read(projectsProvider.notifier).switchTo(b.id);

      expect((await repo.activeProject())!.id, b.id);
    });
  });

  group('state that is not on disk is cleared when the project changes', () {
    test('open request, response, selections, filters and expanded folders', () async {
      container.read(requestDraftProvider.notifier).setUrl('https://typed.test');
      container.read(selectedFlowIdProvider.notifier).state = 'f-a';
      container.read(selectedEnvironmentIdProvider.notifier).state = 'env-a';
      container.read(expandedGroupIdsProvider.notifier).state = {'g-a'};
      container.read(sidebarSearchQueryProvider.notifier).state = 'pay';
      container.read(sidebarMethodFilterProvider.notifier).state = 'POST';
      container.read(historySearchQueryProvider.notifier).state = 'login';

      await container.read(projectsProvider.notifier).switchTo(b.id);

      expect(container.read(requestDraftProvider).url, isEmpty);
      expect(container.read(requestDraftProvider).id, draftEndpointId);
      expect(container.read(sendStateProvider).response, isNull);
      expect(container.read(selectedFlowIdProvider), isNull);
      expect(container.read(selectedEnvironmentIdProvider), isNull);
      expect(container.read(expandedGroupIdsProvider), isEmpty);
      expect(container.read(sidebarSearchQueryProvider), isEmpty);
      expect(container.read(sidebarMethodFilterProvider), allMethods);
      expect(container.read(historySearchQueryProvider), isEmpty);
    });

    test('a response shown for the old project is gone', () async {
      final executor = _SlowExecutor()..reply.complete(const ExecutedResponse(status: 200));
      container = await open(extra: [requestExecutorProvider.overrideWithValue(executor)]);
      await container.read(environmentsProvider.future);
      await container.read(sendStateProvider.notifier).send();
      expect(container.read(sendStateProvider).response!.status, 200);

      await container.read(projectsProvider.notifier).switchTo(b.id);

      expect(container.read(sendStateProvider).response, isNull);
    });

    test('a token captured in one project is not used in another', () async {
      container = await open();
      await container.read(environmentsProvider.future);
      // Same environment id in both projects would still be two sessions: ids are per project.
      container.read(sessionsProvider.notifier).update('env-a', const Session(accessToken: 'tok-a'));
      expect(container.read(activeSessionProvider).accessToken, 'tok-a');

      await container.read(projectsProvider.notifier).switchTo(b.id);
      await container.read(environmentsProvider.future);

      expect(container.read(activeSessionProvider).accessToken, isEmpty);
    });

    test('a session kept for "no environment" does not follow to another project', () async {
      container.read(sessionsProvider.notifier).update(noEnvironmentKey, const Session(accessToken: 'loose'));

      await container.read(projectsProvider.notifier).switchTo(b.id);

      expect(container.read(sessionsProvider.notifier).sessionFor(noEnvironmentKey).accessToken, isEmpty);
    });
  });

  group('a send that is still running when the project changes', () {
    test('records its history in the project it started in and does not touch the new one', () async {
      final executor = _SlowExecutor();
      container = await open(extra: [requestExecutorProvider.overrideWithValue(executor)]);
      await container.read(environmentsProvider.future);
      final saved = (await (await storeOf(a)).readCollections()).endpoints.single;
      container.read(requestDraftProvider.notifier).loadEndpoint(saved);

      final sending = container.read(sendStateProvider.notifier).send();
      await container.read(projectsProvider.notifier).switchTo(b.id);
      executor.reply.complete(const ExecutedResponse(status: 201));
      await sending;

      expect((await (await storeOf(a)).readHistory('e-a')).map((h) => h.status), [200, 201]);
      expect(await (await storeOf(b)).readHistory('e-a'), isEmpty);
      expect(container.read(sendStateProvider).response, isNull);
      expect(container.read(sendStateProvider).loading, isFalse);
    });
  });

  group('without projects configured', () {
    test('it behaves as a single project over the store in jsonStoreProvider', () async {
      final store = JsonStore.inMemory();
      await store.writeFlows([const Flow(id: 'only', name: 'Only')]);
      final plain = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(store)]);
      addTearDown(plain.dispose);

      expect((await plain.read(flowsProvider.future)).single.id, 'only');
      expect(plain.read(projectsProvider).projects, hasLength(1));
      expect(plain.read(projectsProvider).active.name, 'Default');
    });

    test('changing projects is not available', () async {
      final plain = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(JsonStore.inMemory())]);
      addTearDown(plain.dispose);

      await expectLater(plain.read(projectsProvider.notifier).create('x'), throwsStateError);
    });
  });
}
