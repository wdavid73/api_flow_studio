import 'dart:io';

import 'package:api_flow_studio/engine/projects/projects_repository.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journey_harness.dart';

/// Keeps the data on a real temporary folder, laid out the way the app does it
/// (`projects.json` plus `projects/<id>/…`), so persistence goes through the
/// actual files. Each store gets its own folder, removed when the test ends.
class DiskHarness extends JourneyHarness {
  /// The data folder of the most recently created store, for tests that inspect it.
  Directory? lastDirectory;

  final Map<JsonStore, ProjectsRepository> _repositoryOf = {};
  final Map<ProjectsRepository, Directory> _rootOf = {};

  @override
  Future<JsonStore> newStore() async {
    final dir = await Directory.systemTemp.createTemp('api_flow_journey_');
    lastDirectory = dir;
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    final repository = ProjectsRepository.disk(dir);
    await repository.ensureDefaultProject();
    _rootOf[repository] = dir;
    final store = await repository.storeFor((await repository.activeProject())!.id);
    _repositoryOf[store] = repository;
    return store;
  }

  @override
  Future<ProjectsRepository> openProjects(JsonStore store) async => _repositoryOf[store] ?? await super.openProjects(store);

  @override
  Future<ProjectsRepository> reopenProjects(ProjectsRepository current) async {
    final root = _rootOf[current];
    if (root == null) return current;
    final reopened = ProjectsRepository.disk(root);
    await reopened.ensureDefaultProject();
    _rootOf[reopened] = root;
    return reopened;
  }
}
