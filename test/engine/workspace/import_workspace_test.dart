import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/projects/projects_repository.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/engine/workspace/export_workspace.dart';
import 'package:api_flow_studio/engine/workspace/import_workspace.dart';
import 'package:api_flow_studio/engine/workspace/workspace_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProjectsRepository repo;

  final file = WorkspaceFile(
    name: 'commodo',
    colorIndex: 3,
    environments: const [
      Environment(id: 'dev', name: 'Dev', variables: {
        'base_url': EnvironmentVariable(value: 'https://dev.test'),
        'api_key': EnvironmentVariable(value: '', secret: true),
      }),
      Environment(id: 'prod', name: 'Prod', variables: {'base_url': EnvironmentVariable(value: 'https://prod.test')}),
    ],
    groups: const [
      Group(id: 'g-root', name: 'Auth'),
      Group(id: 'g-child', name: 'Sessions', parentGroupId: 'g-root'),
    ],
    endpoints: const [
      Endpoint(id: 'e-login', groupId: 'g-root', name: 'Login', method: 'POST', url: '{{base_url}}/login'),
      Endpoint(
        id: 'e-me',
        groupId: 'g-child',
        name: 'Me',
        method: 'GET',
        url: '{{base_url}}/me',
        authConfig: AuthConfig.bearer(token: ''),
      ),
    ],
    flows: const [
      Flow(id: 'f-signup', name: 'Signup', steps: [
        FlowStep(endpointId: 'e-login', extract: {'tok': 'response.body.token'}),
        FlowStep(endpointId: 'e-me'),
        FlowStep(endpointId: 'e-gone'), // already dangling in the source
      ]),
    ],
    hostNotes: const {'base_url': 'Main API'},
    exportedAt: DateTime.utc(2026, 10, 3),
  );

  setUp(() async {
    repo = ProjectsRepository.inMemory();
    await repo.create('existing');
  });

  Future<JsonStore> storeOf(ImportedWorkspace imported) => repo.storeFor(imported.project.id);

  group('creating the project', () {
    test('adds a new project with the name and color of the file', () async {
      final imported = await importWorkspace(repo, file);

      expect(imported.project.name, 'commodo');
      expect(imported.project.colorIndex, 3);
      expect((await repo.projects()).map((p) => p.name), ['existing', 'commodo']);
    });

    test('it stays inactive unless asked to activate', () async {
      final quiet = await importWorkspace(repo, file);
      expect((await repo.activeProject())!.id, isNot(quiet.project.id));

      final loud = await importWorkspace(repo, file, activate: true);
      expect((await repo.activeProject())!.id, loud.project.id);
    });

    test('reports how many secrets the person has to fill in', () async {
      final imported = await importWorkspace(repo, file);

      expect(imported.secretsToFill, 2); // api_key in Dev and the empty bearer token
    });

    test('a name that is taken gets a number, whatever its casing', () async {
      await repo.create('Commodo');

      final imported = await importWorkspace(repo, file);

      expect(imported.project.name, 'commodo (2)');
    });

    test('importing the same file again gives each copy its own name', () async {
      final first = await importWorkspace(repo, file);
      final second = await importWorkspace(repo, file);
      final third = await importWorkspace(repo, file);

      expect([first, second, third].map((i) => i.project.name), ['commodo', 'commodo (2)', 'commodo (3)']);
    });

    test('a long name still fits the limit once the number is added', () async {
      final long = WorkspaceFile(name: 'x' * 40, exportedAt: DateTime.utc(2026));
      await importWorkspace(repo, long);

      final second = await importWorkspace(repo, long);

      expect(second.project.name, hasLength(lessThanOrEqualTo(maxProjectNameLength)));
      expect(second.project.name, endsWith(' (2)'));
    });

    test('a name over the limit in the file is shortened', () async {
      final imported = await importWorkspace(repo, WorkspaceFile(name: 'y' * 60, exportedAt: DateTime.utc(2026)));

      expect(imported.project.name, hasLength(maxProjectNameLength));
    });
  });

  group('the data of the new project', () {
    test('is everything in the file, and no active environment', () async {
      final store = await storeOf(await importWorkspace(repo, file));

      expect((await store.readEnvironments()).map((e) => e.name), ['Dev', 'Prod']);
      expect((await store.readEnvironments()).first.variables['base_url']!.value, 'https://dev.test');
      expect((await store.readEnvironments()).first.variables['api_key']!.secret, isTrue);
      final collections = await store.readCollections();
      expect(collections.groups.map((g) => g.name), ['Auth', 'Sessions']);
      expect(collections.endpoints.map((e) => e.name), ['Login', 'Me']);
      expect(collections.endpoints.last.authConfig, const AuthConfig.bearer(token: ''));
      expect((await store.readFlows()).single.name, 'Signup');
      expect(await store.readHostNotes(), {'base_url': 'Main API'});
      expect(await store.readActiveEnvironmentId(), isNull);
      expect(await store.readAllHistory(), isEmpty);
    });

    test('every id is new, and the links between things follow the new ids', () async {
      final store = await storeOf(await importWorkspace(repo, file));
      final envs = await store.readEnvironments();
      final collections = await store.readCollections();
      final flow = (await store.readFlows()).single;

      final oldIds = {'dev', 'prod', 'g-root', 'g-child', 'e-login', 'e-me', 'f-signup'};
      final newIds = [
        ...envs.map((e) => e.id),
        ...collections.groups.map((g) => g.id),
        ...collections.endpoints.map((e) => e.id),
        flow.id,
      ];
      expect(newIds.toSet(), hasLength(newIds.length));
      expect(newIds.any(oldIds.contains), isFalse);

      final root = collections.groups.firstWhere((g) => g.name == 'Auth');
      final child = collections.groups.firstWhere((g) => g.name == 'Sessions');
      expect(root.parentGroupId, isNull);
      expect(child.parentGroupId, root.id);
      final login = collections.endpoints.firstWhere((e) => e.name == 'Login');
      final me = collections.endpoints.firstWhere((e) => e.name == 'Me');
      expect(login.groupId, root.id);
      expect(me.groupId, child.id);
      expect(flow.steps.map((s) => s.endpointId).take(2), [login.id, me.id]);
      expect(flow.steps.first.extract, {'tok': 'response.body.token'});
    });

    test('a step that already pointed at nothing keeps pointing at nothing', () async {
      final store = await storeOf(await importWorkspace(repo, file));

      expect((await store.readFlows()).single.steps.last.endpointId, 'e-gone');
    });

    test('two copies share no ids', () async {
      final a = await (await storeOf(await importWorkspace(repo, file))).readCollections();
      final b = await (await storeOf(await importWorkspace(repo, file))).readCollections();

      final idsA = {...a.groups.map((g) => g.id), ...a.endpoints.map((e) => e.id)};
      final idsB = {...b.groups.map((g) => g.id), ...b.endpoints.map((e) => e.id)};
      expect(idsA.intersection(idsB), isEmpty);
    });

    test('editing the copy leaves the original project alone', () async {
      final original = (await repo.projects()).single;
      await (await repo.storeFor(original.id)).writeFlows([const Flow(id: 'mine', name: 'Mine')]);

      final copy = await storeOf(await importWorkspace(repo, file));
      await copy.writeFlows([]);

      expect((await (await repo.storeFor(original.id)).readFlows()).single.id, 'mine');
    });
  });

  group('a round trip', () {
    test('exporting a project and importing the file gives the same content with new ids', () async {
      final source = JsonStore.inMemory();
      await source.writeEnvironments([
        const Environment(id: 'e1', name: 'Dev', variables: {
          'base_url': EnvironmentVariable(value: 'https://dev.test'),
          'key': EnvironmentVariable(value: 'SECRET', secret: true),
        }),
      ]);
      await source.writeCollections(
        groups: const [Group(id: 'g1', name: 'API')],
        endpoints: const [Endpoint(id: 'x1', groupId: 'g1', name: 'List', method: 'GET', url: '{{base_url}}/items')],
      );
      await source.writeFlows([const Flow(id: 'f1', name: 'Flow', steps: [FlowStep(endpointId: 'x1')])]);
      await source.writeHostNotes({'base_url': 'note'});
      final project = (await repo.projects()).single;
      final exported = await exportWorkspace(source, project);

      final imported = await importWorkspace(repo, WorkspaceFile.parse(exported.encode()));
      final store = await storeOf(imported);

      final env = (await store.readEnvironments()).single;
      expect(env.name, 'Dev');
      expect(env.variables['key']!.value, isEmpty);
      expect(env.variables['key']!.secret, isTrue);
      expect(env.variables['base_url']!.value, 'https://dev.test');
      final endpoint = (await store.readCollections()).endpoints.single;
      expect(endpoint.url, '{{base_url}}/items');
      expect((await store.readFlows()).single.steps.single.endpointId, endpoint.id);
      expect(await store.readHostNotes(), {'base_url': 'note'});
    });
  });

  group('importing text', () {
    test('reads the text and imports it', () async {
      final imported = await importWorkspaceText(repo, file.encode());

      expect(imported.project.name, 'commodo');
    });

    test('an invalid file creates nothing', () async {
      await expectLater(importWorkspaceText(repo, '{ nope'), throwsA(isA<WorkspaceFileException>()));
      await expectLater(importWorkspaceText(repo, '{"format":"other"}'), throwsA(isA<WorkspaceFileException>()));

      expect((await repo.projects()).map((p) => p.name), ['existing']);
    });
  });

  group('when something fails half way', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('api_flow_import_');
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
    });

    test('the partial project is removed and the error is raised', () async {
      var counter = 0;
      final disk = ProjectsRepository.disk(root, newId: () => 'p-${counter++}');
      await disk.create('existing'); // p-0
      // The folder the next project would use is a file: writing its data fails.
      Directory('${root.path}/projects').createSync(recursive: true);
      File('${root.path}/projects/p-1').writeAsStringSync('in the way');

      await expectLater(importWorkspace(disk, file), throwsA(isA<FileSystemException>()));

      expect((await disk.projects()).map((p) => p.name), ['existing']);
      expect((await disk.activeProject())!.name, 'existing');
    });
  });
}
