import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/projects/projects_repository.dart';
import 'package:api_flow_studio/engine/storage/key_value_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryBackend backend;

  ProjectsRepository open() => ProjectsRepository.web(backend);

  setUp(() => backend = MemoryBackend());

  test('starts with an empty Default project', () async {
    final repository = open();
    await repository.ensureDefaultProject();

    expect((await repository.projects()).map((p) => p.name), ['Default']);
    expect(await (await repository.storeFor((await repository.activeProject())!.id)).readFlows(), isEmpty);
  });

  test('projects and their data are still there for a repository opened later (a reload)', () async {
    final first = open();
    await first.ensureDefaultProject();
    final created = await first.create('Staging', colorIndex: 2);
    await first.setActive(created.id);
    await (await first.storeFor(created.id)).writeFlows(const [Flow(id: 'f', name: 'Login')]);

    final second = open();
    await second.ensureDefaultProject(); // does nothing: projects exist

    expect((await second.projects()).map((p) => p.name), ['Default', 'Staging']);
    expect((await second.activeProject())!.id, created.id);
    expect((await (await second.storeFor(created.id)).readFlows()).single.name, 'Login');
  });

  test('two projects keep their own data', () async {
    final repository = open();
    await repository.ensureDefaultProject();
    final a = (await repository.activeProject())!;
    final b = await repository.create('Other');
    await (await repository.storeFor(a.id)).writeFlows(const [Flow(id: 'f', name: 'Only in A')]);

    expect(await (await repository.storeFor(b.id)).readFlows(), isEmpty);
  });

  test('deleting a project removes its data and leaves the others', () async {
    final repository = open();
    await repository.ensureDefaultProject();
    final keep = (await repository.activeProject())!;
    final doomed = await repository.create('Doomed');
    await (await repository.storeFor(doomed.id)).writeFlows(const [Flow(id: 'f', name: 'x')]);
    await (await repository.storeFor(keep.id)).writeFlows(const [Flow(id: 'g', name: 'kept')]);

    await repository.delete(doomed.id);

    expect(await backend.keysWithPrefix('p:${doomed.id}:'), isEmpty);
    expect(await backend.keysWithPrefix('p:${keep.id}:'), isNotEmpty);
    expect((await repository.projects()).map((p) => p.name), ['Default']);
  });
}
