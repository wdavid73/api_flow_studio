import 'package:api_flow_studio/engine/import/import_result.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/ui/collections/collections_provider.dart';
import 'package:api_flow_studio/ui/environments/environments_provider.dart';
import 'package:api_flow_studio/ui/import/import_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A store whose environments file cannot be written, to see what a failure leaves behind.
class EnvironmentsFailingStore extends JsonStore {
  EnvironmentsFailingStore() : super.inMemory();

  int environmentWrites = 0;

  @override
  Future<void> writeEnvironments(List<Environment> environments) async {
    environmentWrites++;
    throw const FileSystemExceptionStandIn();
  }
}

class FileSystemExceptionStandIn implements Exception {
  const FileSystemExceptionStandIn();
}

Endpoint endpoint(String id, String groupId, String name, {RequestBody body = const RequestBody.none()}) =>
    Endpoint(id: id, groupId: groupId, name: name, method: 'GET', url: 'https://x.test/$id', body: body);

void main() {
  late JsonStore store;
  late ProviderContainer container;

  ProviderContainer containerFor(JsonStore s) {
    final c = ProviderContainer(overrides: [jsonStoreProvider.overrideWithValue(s)]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    store = JsonStore.inMemory();
    container = containerFor(store);
  });

  Future<ImportSummary> apply(ImportResult result, [ProviderContainer? on]) {
    return applyImport((on ?? container).read, result);
  }

  Future<CollectionsState> collections([ProviderContainer? on]) => (on ?? container).read(collectionsProvider.future);
  Future<EnvironmentsState> environments([ProviderContainer? on]) => (on ?? container).read(environmentsProvider.future);

  const petstore = ImportResult(
    source: 'Test format',
    groups: [
      Group(id: 'root', name: 'Petstore'),
      Group(id: 'pets', name: 'Pets', parentGroupId: 'root'),
    ],
    endpoints: [
      Endpoint(id: 'e1', groupId: 'root', name: 'Health', method: 'GET', url: '/health'),
      Endpoint(id: 'e2', groupId: 'pets', name: 'List pets', method: 'GET', url: '/pets'),
    ],
  );

  group('the folders and requests', () {
    test('are added with new ids and the summary counts what came in', () async {
      final summary = await apply(petstore);

      final state = await collections();
      expect(state.groups.map((g) => g.name), ['Petstore', 'Pets']);
      expect(state.groups.map((g) => g.id), isNot(contains('root')));
      expect(state.endpoints.map((e) => e.name), ['Health', 'List pets']);
      expect(summary.source, 'Test format');
      expect(summary.folders, 2);
      expect(summary.requests, 2);
      expect(summary.environments, 0);
      expect(summary.valuesToFill, 0);
      expect((await store.readCollections()).endpoints, hasLength(2));
    });

    test('keep the structure: the subfolder hangs from the new root', () async {
      await apply(petstore);

      final state = await collections();
      final root = state.groups.firstWhere((g) => g.name == 'Petstore');
      final pets = state.groups.firstWhere((g) => g.name == 'Pets');
      expect(pets.parentGroupId, root.id);
      expect(state.endpoints.firstWhere((e) => e.name == 'List pets').groupId, pets.id);
    });

    test('never touch what was already there', () async {
      final notifier = container.read(collectionsProvider.notifier);
      final existing = await notifier.createGroup('Mine');
      await notifier.createEndpoint(endpoint('mine', existing.id, 'My request'));

      await apply(petstore);

      final state = await collections();
      expect(state.groups.first, existing);
      expect(state.endpoints.first.id, 'mine');
      expect(state.groups, hasLength(3));
    });

    test('the summary carries the importer\'s warnings', () async {
      const warning = ImportWarning(where: 'Pets / List', message: 'script ignored');

      final summary = await apply(const ImportResult(source: 'S', groups: [Group(id: 'g', name: 'G')], endpoints: [Endpoint(id: 'e', groupId: 'g', name: 'n', method: 'GET', url: '/')], warnings: [warning]));

      expect(summary.warnings.single.where, 'Pets / List');
    });

    test('lose the path of every file field', () async {
      await apply(ImportResult(
        source: 'S',
        groups: const [Group(id: 'g', name: 'G')],
        endpoints: [
          endpoint('e', 'g', 'Upload', body: const RequestBody.multipart([MultipartField(name: 'f', kind: MultipartFieldKind.file, value: '/Users/someone/secret.pem')])),
        ],
      ));

      final fields = (await collections()).endpoints.single.body.maybeMap(multipart: (b) => b.fields, orElse: () => throw StateError('not multipart'));
      expect(fields.single.value, '');
    });
  });

  group('values to fill in', () {
    Endpoint upload(List<MultipartField> fields) =>
        endpoint('up', 'g', 'Upload', body: RequestBody.multipart(fields));

    ImportResult withFiles(List<MultipartField> fields, {List<Environment> environments = const []}) => ImportResult(
          source: 'S',
          groups: const [Group(id: 'g', name: 'G')],
          endpoints: [upload(fields)],
          environments: environments,
        );

    test('an enabled file field is a file still to choose', () async {
      final summary = await apply(withFiles(const [
        MultipartField(name: 'a', kind: MultipartFieldKind.file, value: '/Users/someone/a.png'),
        MultipartField(name: 'b', kind: MultipartFieldKind.file),
        MultipartField(name: 'text', value: 'x'),
      ]));

      expect(summary.valuesToFill, 2);
    });

    test('a disabled file field is not', () async {
      final summary = await apply(withFiles(const [MultipartField(name: 'a', kind: MultipartFieldKind.file, enabled: false)]));

      expect(summary.valuesToFill, 0);
    });

    test('files add up with the secrets of the imported environments', () async {
      final summary = await apply(withFiles(
        const [MultipartField(name: 'a', kind: MultipartFieldKind.file)],
        environments: const [
          Environment(id: 'x', name: 'Dev', variables: {'api_key': EnvironmentVariable(value: '', secret: true)}),
        ],
      ));

      expect(summary.valuesToFill, 2);
      expect(summary.describe(), endsWith(' — 2 values to fill in'));
    });
  });

  group('root folder names', () {
    List<String> rootNames(CollectionsState s) => [for (final g in s.groups) if (g.parentGroupId == null) g.name];

    test('a root that is already there is numbered', () async {
      await container.read(collectionsProvider.notifier).createGroup('Petstore');

      await apply(petstore);

      expect(rootNames(await collections()), ['Petstore', 'Petstore (2)']);
    });

    test('importing the same file again numbers it again', () async {
      await apply(petstore);
      await apply(petstore);
      await apply(petstore);

      expect(rootNames(await collections()), ['Petstore', 'Petstore (2)', 'Petstore (3)']);
    });

    test('ignores the case', () async {
      await container.read(collectionsProvider.notifier).createGroup('PETSTORE');

      await apply(petstore);

      expect(rootNames(await collections()), ['PETSTORE', 'Petstore (2)']);
    });

    test('two roots with the same name in one file are numbered between themselves', () async {
      await apply(const ImportResult(
        source: 'S',
        groups: [Group(id: 'a', name: 'Same'), Group(id: 'b', name: 'Same')],
        endpoints: [Endpoint(id: 'e', groupId: 'a', name: 'n', method: 'GET', url: '/')],
      ));

      expect(rootNames(await collections()), ['Same', 'Same (2)']);
    });

    test('a subfolder never makes a root of the same file take a number, and a root never numbers a subfolder', () async {
      await container.read(collectionsProvider.notifier).createGroup('Pets');

      await apply(const ImportResult(
        source: 'S',
        groups: [
          Group(id: 'a', name: 'Petstore'),
          Group(id: 'sub', name: 'Pets', parentGroupId: 'a'),
          Group(id: 'b', name: 'Pets'),
        ],
        endpoints: [Endpoint(id: 'e', groupId: 'sub', name: 'n', method: 'GET', url: '/')],
      ));

      final state = await collections();
      final byParent = {for (final g in state.groups) g.id: g};
      final names = state.groups.map((g) => (g.parentGroupId == null ? 'root:' : 'sub:') + g.name).toList();
      expect(names, ['root:Pets', 'root:Petstore', 'sub:Pets', 'root:Pets (2)']);
      expect(byParent.length, 4);
    });

    test('subfolders keep their names even when another folder has the same one', () async {
      final notifier = container.read(collectionsProvider.notifier);
      final other = await notifier.createGroup('Other');
      await notifier.createGroup('Pets', parentGroupId: other.id);

      await apply(petstore);

      final names = (await collections()).groups.map((g) => g.name).toList();
      expect(names.where((n) => n == 'Pets'), hasLength(2));
    });
  });

  group('environments', () {
    const dev = Environment(id: 'x', name: 'Dev', variables: {
      'base_url': EnvironmentVariable(value: 'https://dev.test'),
      'api_key': EnvironmentVariable(value: '', secret: true),
      'token': EnvironmentVariable(value: 'kept', secret: true),
      'optional_note': EnvironmentVariable(value: ''), // empty, but not a secret: nothing to fill in
    });

    ImportResult withEnvironments(List<Environment> list) => ImportResult(source: 'S', groups: petstore.groups, endpoints: petstore.endpoints, environments: list);

    test('are added with new ids, never made active, and the summary counts them and the secrets to fill', () async {
      final summary = await apply(withEnvironments([dev]));

      final state = await environments();
      expect(state.environments.single.name, 'Dev');
      expect(state.environments.single.id, isNot('x'));
      expect(state.environments.single.variables['base_url']!.value, 'https://dev.test');
      expect(state.activeEnvironmentId, isNull);
      expect(summary.environments, 1);
      expect(summary.valuesToFill, 1);
      expect((await store.readEnvironments()).single.name, 'Dev');
    });

    test('a name that is already taken is numbered', () async {
      await container.read(environmentsProvider.notifier).create('dev');

      await apply(withEnvironments([dev, dev]));

      expect((await environments()).environments.map((e) => e.name), ['dev', 'Dev (2)', 'Dev (3)']);
    });

    test('the active environment stays the active one', () async {
      final notifier = container.read(environmentsProvider.notifier);
      await notifier.create('Mine');
      final mine = (await environments()).environments.single;
      await notifier.setActive(mine.id);

      await apply(withEnvironments([dev]));

      final state = await environments();
      expect(state.activeEnvironmentId, mine.id);
      expect(state.environments.map((e) => e.name), ['Mine', 'Dev']);
    });

    test('a file with only environments is applied too', () async {
      final summary = await apply(const ImportResult(source: 'Env file', environments: [dev]));

      expect(summary.requests, 0);
      expect(summary.folders, 0);
      expect(summary.environments, 1);
      expect((await collections()).groups, isEmpty);
    });
  });

  group('all or nothing', () {
    test('when the environments cannot be written, the folders and requests are put back', () async {
      final failing = EnvironmentsFailingStore();
      final c = containerFor(failing);
      final notifier = c.read(collectionsProvider.notifier);
      final existing = await notifier.createGroup('Mine');
      final before = await collections(c);

      await expectLater(
        apply(ImportResult(source: 'S', groups: petstore.groups, endpoints: petstore.endpoints, environments: const [Environment(id: 'x', name: 'Dev')]), c),
        throwsA(isA<FileSystemExceptionStandIn>()),
      );

      final after = await collections(c);
      expect(after.groups, before.groups);
      expect(after.endpoints, before.endpoints);
      expect(after.groups.single, existing);
      expect((await environments(c)).environments, isEmpty, reason: 'nothing shows as imported that was not saved');
      final onDisk = await failing.readCollections();
      expect(onDisk.groups, before.groups);
      expect(onDisk.endpoints, isEmpty);
    });

    test('with no environments the environments file is not even touched', () async {
      final failing = EnvironmentsFailingStore();
      final c = containerFor(failing);

      await apply(petstore, c);

      expect(failing.environmentWrites, 0);
      expect((await collections(c)).groups, hasLength(2));
    });

    test('a later import still works after a failed one', () async {
      final failing = EnvironmentsFailingStore();
      final c = containerFor(failing);
      await expectLater(
        apply(ImportResult(source: 'S', groups: petstore.groups, endpoints: petstore.endpoints, environments: const [Environment(id: 'x', name: 'Dev')]), c),
        throwsA(isA<Object>()),
      );

      final summary = await apply(petstore, c);

      expect(summary.requests, 2);
      expect((await collections(c)).groups.map((g) => g.name), ['Petstore', 'Pets']);
    });
  });
}
