import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/projects/projects_repository.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('api_flow_migration_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
  });

  const dataFiles = [
    'environments.json',
    'settings.json',
    'collections.json',
    'flows.json',
    'history.json',
    'host_notes.json',
  ];

  /// What an installation from before projects left in the data folder.
  Future<void> writeLegacyData() async {
    final legacy = JsonStore(directory: root);
    await legacy.writeEnvironments([
      const Environment(id: 'dev', name: 'Dev', variables: {'base_url': EnvironmentVariable(value: 'https://dev.test')}),
    ]);
    await legacy.writeActiveEnvironmentId('dev');
    await legacy.writeCollections(
      groups: const [Group(id: 'g1', name: 'Demo')],
      endpoints: const [Endpoint(id: 'e1', groupId: 'g1', name: 'List', method: 'GET', url: '{{base_url}}/items')],
    );
    await legacy.writeFlows([const Flow(id: 'f1', name: 'Flow')]);
    await legacy.writeHostNotes({'base_url': 'Main API'});
    await legacy.appendHistoryEntry(
      'e1',
      HistoryEntry(id: 'h1', endpointId: 'e1', timestamp: DateTime.utc(2026, 10, 1), status: 200, headers: const {}, body: '{}', elapsedMs: 5),
    );
  }

  bool rootHas(String name) => File('${root.path}/$name').existsSync();

  test('data from before projects becomes the Default project, untouched', () async {
    await writeLegacyData();
    final repo = ProjectsRepository.disk(root);

    await repo.ensureDefaultProject();

    final projects = await repo.projects();
    expect(projects.map((p) => p.name), ['Default']);
    expect((await repo.activeProject())!.id, projects.single.id);
    final store = await repo.storeFor(projects.single.id);
    expect((await store.readEnvironments()).single.variables['base_url']!.value, 'https://dev.test');
    expect(await store.readActiveEnvironmentId(), 'dev');
    expect((await store.readCollections()).endpoints.single.id, 'e1');
    expect((await store.readFlows()).single.id, 'f1');
    expect(await store.readHostNotes(), {'base_url': 'Main API'});
    expect((await store.readHistory('e1')).single.id, 'h1');
  });

  test('the data folder no longer holds the data files afterwards', () async {
    await writeLegacyData();

    await ProjectsRepository.disk(root).ensureDefaultProject();

    for (final name in dataFiles) {
      expect(rootHas(name), isFalse, reason: name);
    }
    expect(rootHas('projects.json'), isTrue);
  });

  test('with no data at all it creates an empty Default project', () async {
    final repo = ProjectsRepository.disk(root);

    await repo.ensureDefaultProject();

    final project = (await repo.projects()).single;
    expect(project.name, 'Default');
    expect(await (await repo.storeFor(project.id)).readEnvironments(), isEmpty);
  });

  test('running it again changes nothing: no second project, no duplicated files', () async {
    await writeLegacyData();
    final first = ProjectsRepository.disk(root);
    await first.ensureDefaultProject();
    final id = (await first.projects()).single.id;

    final second = ProjectsRepository.disk(root);
    await second.ensureDefaultProject();
    await second.ensureDefaultProject();

    expect((await second.projects()).map((p) => p.id), [id]);
    expect(Directory('${root.path}/projects').listSync(), hasLength(1));
    expect((await (await second.storeFor(id)).readFlows()), hasLength(1));
  });

  test('when projects already exist, old files in the root are left alone', () async {
    final repo = ProjectsRepository.disk(root);
    await repo.create('mine');
    await JsonStore(directory: root).writeFlows([const Flow(id: 'stray', name: 'x')]);

    await repo.ensureDefaultProject();

    expect((await repo.projects()).map((p) => p.name), ['mine']);
    expect(rootHas('flows.json'), isTrue);
  });

  test('a failure while moving keeps every original and the next start retries', () async {
    await writeLegacyData();
    // `projects` being a file makes it impossible to create a project folder.
    final blocker = File('${root.path}/projects')..writeAsStringSync('in the way');
    final repo = ProjectsRepository.disk(root);

    await expectLater(repo.ensureDefaultProject(), throwsA(isA<FileSystemException>()));

    for (final name in dataFiles) {
      expect(rootHas(name), isTrue, reason: '$name was lost');
    }
    expect(rootHas('projects.json'), isFalse);

    blocker.deleteSync();
    final retry = ProjectsRepository.disk(root);
    await retry.ensureDefaultProject();

    final store = await retry.storeFor((await retry.projects()).single.id);
    expect((await store.readFlows()).single.id, 'f1');
  });

  test('backups and temporary files are not mistaken for data', () async {
    File('${root.path}/flows.json.corrupt-123').writeAsStringSync('junk');
    File('${root.path}/environments.json.tmp-9').writeAsStringSync('junk');
    final repo = ProjectsRepository.disk(root);

    await repo.ensureDefaultProject();

    final project = (await repo.projects()).single;
    expect(await (await repo.storeFor(project.id)).readFlows(), isEmpty);
    expect(File('${root.path}/flows.json.corrupt-123').existsSync(), isTrue);
  });

  test('in memory it creates an empty Default project once', () async {
    final repo = ProjectsRepository.inMemory();

    await repo.ensureDefaultProject();
    await repo.ensureDefaultProject();

    expect((await repo.projects()).map((p) => p.name), ['Default']);
  });
}
