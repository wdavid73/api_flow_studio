import 'dart:convert';
import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/projects/projects_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('api_flow_projects_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
  });

  // The same behaviour on both backends.
  final backends = <String, ProjectsRepository Function()>{
    'in memory': ProjectsRepository.inMemory,
    'on disk': () => ProjectsRepository.disk(root),
  };

  for (final entry in backends.entries) {
    group(entry.key, () {
      late ProjectsRepository repo;

      setUp(() => repo = entry.value());

      test('starts with no projects', () async {
        expect(await repo.projects(), isEmpty);
        expect(await repo.activeProject(), isNull);
      });

      test('the first project created becomes the active one', () async {
        final first = await repo.create('commodo');

        expect((await repo.activeProject())!.id, first.id);
      });

      test('a later project does not take over the active one', () async {
        final first = await repo.create('commodo');
        await repo.create('fin_track_pro');

        expect((await repo.activeProject())!.id, first.id);
        expect((await repo.projects()).map((p) => p.name), ['commodo', 'fin_track_pro']);
      });

      test('setActive switches the active project', () async {
        await repo.create('commodo');
        final second = await repo.create('fin_track_pro');

        await repo.setActive(second.id);

        expect((await repo.activeProject())!.id, second.id);
      });

      test('names are trimmed and the color is kept', () async {
        final project = await repo.create('  commodo  ', colorIndex: 3);

        expect(project.name, 'commodo');
        expect(project.colorIndex, 3);
      });

      test('rename changes only the name', () async {
        final project = await repo.create('commodo', colorIndex: 2);

        final renamed = await repo.rename(project.id, 'Commodo API');

        expect(renamed.name, 'Commodo API');
        expect(renamed.id, project.id);
        expect(renamed.colorIndex, 2);
        expect((await repo.projects()).single.name, 'Commodo API');
      });

      test('a project can be renamed to a different casing of its own name', () async {
        final project = await repo.create('commodo');

        final renamed = await repo.rename(project.id, 'Commodo');

        expect(renamed.name, 'Commodo');
      });

      test('an empty or blank name is rejected', () async {
        for (final name in ['', '   ']) {
          await expectLater(
            repo.create(name),
            throwsA(isA<InvalidProjectName>().having((e) => e.reason, 'reason', ProjectNameProblem.empty)),
          );
        }
        expect(await repo.projects(), isEmpty);
      });

      test('a name longer than 40 characters is rejected, exactly 40 is fine', () async {
        await expectLater(
          repo.create('x' * 41),
          throwsA(isA<InvalidProjectName>().having((e) => e.reason, 'reason', ProjectNameProblem.tooLong)),
        );

        expect((await repo.create('x' * 40)).name, hasLength(40));
      });

      test('a repeated name is rejected whatever its casing', () async {
        await repo.create('commodo');

        await expectLater(
          repo.create('COMMODO'),
          throwsA(isA<InvalidProjectName>().having((e) => e.reason, 'reason', ProjectNameProblem.duplicate)),
        );
        final other = await repo.create('fin_track_pro');
        await expectLater(
          repo.rename(other.id, ' commodo '),
          throwsA(isA<InvalidProjectName>().having((e) => e.reason, 'reason', ProjectNameProblem.duplicate)),
        );
      });

      test('each project has its own, independent store', () async {
        final a = await repo.create('a');
        final b = await repo.create('b');

        await (await repo.storeFor(a.id)).writeFlows([const Flow(id: 'f1', name: 'Only in a')]);

        expect((await (await repo.storeFor(a.id)).readFlows()).map((f) => f.id), ['f1']);
        expect(await (await repo.storeFor(b.id)).readFlows(), isEmpty);
      });

      test('the store of a project is the same one every time', () async {
        final a = await repo.create('a');

        await (await repo.storeFor(a.id)).writeFlows([const Flow(id: 'f1', name: 'x')]);

        expect(await (await repo.storeFor(a.id)).readFlows(), hasLength(1));
      });

      test('asking for the store of an unknown project fails', () async {
        await expectLater(repo.storeFor('nope'), throwsA(isA<ProjectNotFound>()));
      });

      test('deleting a project removes its data and keeps the others', () async {
        final a = await repo.create('a');
        final b = await repo.create('b');
        await (await repo.storeFor(a.id)).writeFlows([const Flow(id: 'f1', name: 'x')]);
        await (await repo.storeFor(b.id)).writeFlows([const Flow(id: 'f2', name: 'y')]);

        await repo.delete(b.id);

        expect((await repo.projects()).map((p) => p.id), [a.id]);
        expect(await (await repo.storeFor(a.id)).readFlows(), hasLength(1));
        await expectLater(repo.storeFor(b.id), throwsA(isA<ProjectNotFound>()));
      });

      test('a deleted project leaves no data behind when its name is reused', () async {
        final a = await repo.create('a');
        await repo.create('b');
        await (await repo.storeFor(a.id)).writeFlows([const Flow(id: 'f1', name: 'x')]);
        await repo.delete(a.id);

        final again = await repo.create('a');

        expect(await (await repo.storeFor(again.id)).readFlows(), isEmpty);
      });

      test('deleting the active project activates another one', () async {
        final a = await repo.create('a');
        final b = await repo.create('b');

        await repo.delete(a.id);

        expect((await repo.activeProject())!.id, b.id);
      });

      test('the last project cannot be deleted', () async {
        final only = await repo.create('only');

        await expectLater(repo.delete(only.id), throwsA(isA<LastProjectException>()));

        expect(await repo.projects(), hasLength(1));
      });

      test('deleting or renaming an unknown project fails', () async {
        await repo.create('a');

        await expectLater(repo.delete('nope'), throwsA(isA<ProjectNotFound>()));
        await expectLater(repo.rename('nope', 'x'), throwsA(isA<ProjectNotFound>()));
        await expectLater(repo.setActive('nope'), throwsA(isA<ProjectNotFound>()));
      });

      test('operations fired together all land', () async {
        final created = await Future.wait([for (var i = 0; i < 8; i++) repo.create('p$i')]);

        expect(created.map((p) => p.id).toSet(), hasLength(8));
        expect(await repo.projects(), hasLength(8));
      });
    });
  }

  group('on disk, across restarts', () {
    test('projects, colors, the active one and their data survive reopening', () async {
      final first = ProjectsRepository.disk(root);
      final a = await first.create('commodo', colorIndex: 1);
      final b = await first.create('fin_track_pro', colorIndex: 4);
      await first.setActive(b.id);
      await (await first.storeFor(a.id)).writeFlows([const Flow(id: 'f1', name: 'kept')]);

      final second = ProjectsRepository.disk(root);

      expect((await second.projects()).map((p) => (p.name, p.colorIndex)), [('commodo', 1), ('fin_track_pro', 4)]);
      expect((await second.activeProject())!.id, b.id);
      expect(await (await second.storeFor(a.id)).readFlows(), hasLength(1));
    });

    test('each project keeps its files in its own folder', () async {
      final repo = ProjectsRepository.disk(root);
      final a = await repo.create('a');

      await (await repo.storeFor(a.id)).writeFlows([const Flow(id: 'f1', name: 'x')]);

      expect(File('${root.path}/projects/${a.id}/flows.json').existsSync(), isTrue);
      expect(File('${root.path}/flows.json').existsSync(), isFalse);
    });

    test('deleting a project removes its folder', () async {
      final repo = ProjectsRepository.disk(root);
      final a = await repo.create('a');
      await repo.create('b');
      await (await repo.storeFor(a.id)).writeFlows([const Flow(id: 'f1', name: 'x')]);

      await repo.delete(a.id);

      expect(Directory('${root.path}/projects/${a.id}').existsSync(), isFalse);
    });

    test('a corrupt index is backed up and starts empty', () async {
      await File('${root.path}/projects.json').writeAsString('{ not json');

      final repo = ProjectsRepository.disk(root);

      expect(await repo.projects(), isEmpty);
      final backups = root.listSync().where((e) => e.path.contains('projects.json.corrupt-'));
      expect(backups, hasLength(1));
    });

    test('an active id that no longer exists falls back to the first project', () async {
      final first = ProjectsRepository.disk(root);
      final a = await first.create('a');
      await first.create('b');
      final index = File('${root.path}/projects.json');
      final json = jsonDecode(await index.readAsString()) as Map<String, dynamic>;
      json['activeProjectId'] = 'gone-id';
      await index.writeAsString(jsonEncode(json));

      final second = ProjectsRepository.disk(root);

      expect((await second.activeProject())!.id, a.id);
    });
  });
}
