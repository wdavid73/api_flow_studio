import 'dart:io';

import 'package:uuid/uuid.dart';

import '../storage/json_store.dart';
import 'project.dart';

/// Longest project name accepted.
const int maxProjectNameLength = 40;

enum ProjectNameProblem { empty, tooLong, duplicate }

/// The name given to a project is not acceptable; [reason] says why.
class InvalidProjectName implements Exception {
  const InvalidProjectName(this.reason);

  final ProjectNameProblem reason;

  @override
  String toString() => 'InvalidProjectName(${reason.name})';
}

/// No project has that id.
class ProjectNotFound implements Exception {
  const ProjectNotFound(this.id);

  final String id;

  @override
  String toString() => 'ProjectNotFound($id)';
}

/// The only project left cannot be deleted.
class LastProjectException implements Exception {
  const LastProjectException();

  @override
  String toString() => 'LastProjectException';
}

/// The list of projects, which one is active, and the [JsonStore] each one
/// keeps its data in. The list lives in `projects.json` next to a `projects/`
/// folder holding one directory per project.
///
/// Every operation runs through one queue, so calls fired together (two fast
/// clicks) each see the other's result instead of a stale list.
class ProjectsRepository {
  ProjectsRepository._(this._index, this._open, this._remove, this._now);

  /// Keeps everything under [root] (the real app).
  factory ProjectsRepository.disk(Directory root, {DateTime Function()? now}) {
    String sep(String a, String b) => '$a${Platform.pathSeparator}$b';
    final projectsDir = sep(root.path, 'projects');
    return ProjectsRepository._(
      JsonStore(directory: root),
      (id) => JsonStore(directory: Directory(sep(projectsDir, id))),
      (id) async {
        final dir = Directory(sep(projectsDir, id));
        if (await dir.exists()) await dir.delete(recursive: true);
      },
      now ?? DateTime.now,
    );
  }

  /// Keeps everything in memory (tests, and the web where there are no files).
  factory ProjectsRepository.inMemory({DateTime Function()? now}) =>
      ProjectsRepository._(JsonStore.inMemory(), (_) => JsonStore.inMemory(), (_) async {}, now ?? DateTime.now);

  final JsonStore _index;
  final JsonStore Function(String id) _open;
  final Future<void> Function(String id) _remove;
  final DateTime Function() _now;

  final Map<String, JsonStore> _stores = {};
  Future<void> _queue = Future<void>.value();

  Future<T> _run<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// The stored index with its active id repaired: it always names an existing
  /// project when there is one.
  Future<ProjectIndex> _read() async {
    final index = await _index.readProjectIndex();
    final active = index.projects.any((p) => p.id == index.activeProjectId)
        ? index.activeProjectId
        : index.projects.firstOrNull?.id;
    return ProjectIndex(projects: index.projects, activeProjectId: active);
  }

  Future<List<Project>> projects() => _run(() async => (await _read()).projects);

  Future<Project?> activeProject() => _run(() async {
        final index = await _read();
        return index.projects.where((p) => p.id == index.activeProjectId).firstOrNull;
      });

  /// Adds a project. The first one ever created becomes the active one.
  Future<Project> create(String name, {int colorIndex = 0}) => _run(() async {
        final index = await _read();
        final clean = _validName(name, index.projects, exceptId: null);
        final project = Project(id: const Uuid().v4(), name: clean, colorIndex: colorIndex, createdAt: _now());
        await _index.writeProjectIndex(ProjectIndex(
          projects: [...index.projects, project],
          activeProjectId: index.activeProjectId ?? project.id,
        ));
        return project;
      });

  Future<Project> rename(String id, String name) => _run(() async {
        final index = await _read();
        final project = _find(index, id);
        final renamed = project.copyWith(name: _validName(name, index.projects, exceptId: id));
        await _index.writeProjectIndex(ProjectIndex(
          projects: [for (final p in index.projects) p.id == id ? renamed : p],
          activeProjectId: index.activeProjectId,
        ));
        return renamed;
      });

  Future<void> setActive(String id) => _run(() async {
        final index = await _read();
        _find(index, id);
        await _index.writeProjectIndex(ProjectIndex(projects: index.projects, activeProjectId: id));
      });

  /// Deletes the project and all its data. The last project cannot be deleted;
  /// deleting the active one activates the first remaining.
  Future<void> delete(String id) => _run(() async {
        final index = await _read();
        _find(index, id);
        if (index.projects.length == 1) throw const LastProjectException();

        final remaining = [for (final p in index.projects) if (p.id != id) p];
        final active = index.activeProjectId == id ? remaining.first.id : index.activeProjectId;
        await _index.writeProjectIndex(ProjectIndex(projects: remaining, activeProjectId: active));
        _stores.remove(id);
        await _remove(id);
      });

  /// Where [id] keeps its data: always the same store for the same project.
  Future<JsonStore> storeFor(String id) => _run(() async {
        _find(await _read(), id);
        return _stores.putIfAbsent(id, () => _open(id));
      });

  Project _find(ProjectIndex index, String id) {
    final project = index.projects.where((p) => p.id == id).firstOrNull;
    if (project == null) throw ProjectNotFound(id);
    return project;
  }

  String _validName(String name, List<Project> existing, {required String? exceptId}) {
    final clean = name.trim();
    if (clean.isEmpty) throw const InvalidProjectName(ProjectNameProblem.empty);
    if (clean.length > maxProjectNameLength) throw const InvalidProjectName(ProjectNameProblem.tooLong);
    final taken = existing.any((p) => p.id != exceptId && p.name.toLowerCase() == clean.toLowerCase());
    if (taken) throw const InvalidProjectName(ProjectNameProblem.duplicate);
    return clean;
  }
}
