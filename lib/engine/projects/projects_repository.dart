import 'dart:io';

import 'package:uuid/uuid.dart';

import '../storage/json_store.dart';
import 'project.dart';

/// The files a version without projects kept in the data folder.
const List<String> legacyDataFiles = [
  'environments.json',
  'settings.json',
  'collections.json',
  'flows.json',
  'history.json',
  'host_notes.json',
];

String _randomId() => const Uuid().v4();

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
  ProjectsRepository._(
    this._index,
    this._open,
    this._remove,
    this._now,
    this._newId, {
    this._legacyRoot,
    this._dirFor,
    this._defaultStore,
  });

  /// Keeps everything under [root] (the real app).
  /// [newId] makes the id of each project (a random one by default).
  factory ProjectsRepository.disk(Directory root, {DateTime Function()? now, String Function()? newId}) {
    String sep(String a, String b) => '$a${Platform.pathSeparator}$b';
    final projectsDir = sep(root.path, 'projects');
    Directory dirFor(String id) => Directory(sep(projectsDir, id));
    return ProjectsRepository._(
      JsonStore(directory: root),
      (id) => JsonStore(directory: dirFor(id)),
      (id) async {
        final dir = dirFor(id);
        if (await dir.exists()) await dir.delete(recursive: true);
      },
      now ?? DateTime.now,
      newId ?? _randomId,
      legacyRoot: root,
      dirFor: dirFor,
    );
  }

  /// Keeps everything in memory (tests, and the web where there are no files).
  /// [defaultStore], when given, is the store the project created by
  /// [ensureDefaultProject] uses, so existing data can be wrapped as a project.
  factory ProjectsRepository.inMemory({DateTime Function()? now, JsonStore? defaultStore, String Function()? newId}) =>
      ProjectsRepository._(
        JsonStore.inMemory(),
        (_) => JsonStore.inMemory(),
        (_) async {},
        now ?? DateTime.now,
        newId ?? _randomId,
        defaultStore: defaultStore,
      );

  final JsonStore _index;
  final JsonStore Function(String id) _open;
  final Future<void> Function(String id) _remove;
  final DateTime Function() _now;
  final String Function() _newId;

  /// Disk only: the data folder and where each project's folder is, so data
  /// from before projects existed can be moved into the first project.
  final Directory? _legacyRoot;
  final Directory Function(String id)? _dirFor;

  /// In memory only: the store the Default project adopts.
  final JsonStore? _defaultStore;

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

  /// Makes sure at least one project exists. When there is none, data left in
  /// the data folder by versions without projects becomes the project named
  /// "Default"; with no such data an empty "Default" is created.
  ///
  /// The data is copied first, the index written next and the originals removed
  /// last, so a failure at any point leaves the originals in place and the next
  /// start tries again. Calling it when projects exist does nothing.
  Future<void> ensureDefaultProject() => _run(() async {
        final index = await _read();
        if (index.projects.isNotEmpty) return;

        final id = _newId();
        final originals = await _copyLegacyData(id);
        final project = Project(id: id, name: 'Default', createdAt: _now());
        try {
          await _index.writeProjectIndex(ProjectIndex(projects: [project], activeProjectId: id));
        } catch (_) {
          await _remove(id);
          rethrow;
        }
        final adopted = _defaultStore;
        if (adopted != null) _stores[id] = adopted;
        for (final file in originals) {
          try {
            await file.delete();
          } on FileSystemException {
            // Left behind: harmless, projects.json now exists so it is never read again.
          }
        }
      });

  /// Copies the old data files into project [id]'s folder and returns the
  /// originals to remove once the project is registered. Cleans up and rethrows
  /// if anything goes wrong.
  Future<List<File>> _copyLegacyData(String id) async {
    final root = _legacyRoot;
    final dirFor = _dirFor;
    if (root == null || dirFor == null) return const [];

    final originals = [
      for (final name in legacyDataFiles)
        if (File('${root.path}${Platform.pathSeparator}$name').existsSync())
          File('${root.path}${Platform.pathSeparator}$name'),
    ];
    if (originals.isEmpty) return const [];

    final target = dirFor(id);
    try {
      await target.create(recursive: true);
      for (final file in originals) {
        final name = file.uri.pathSegments.last;
        final copy = await file.copy('${target.path}${Platform.pathSeparator}$name');
        if (await copy.length() != await file.length()) {
          throw FileSystemException('Copy is not the same size as the original', file.path);
        }
      }
    } catch (_) {
      await _remove(id);
      rethrow;
    }
    return originals;
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
        final project = Project(id: _newId(), name: clean, colorIndex: colorIndex, createdAt: _now());
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
    final problem = checkProjectName(name, existing, exceptId: exceptId);
    if (problem != null) throw InvalidProjectName(problem);
    return name.trim();
  }
}

/// What is wrong with [name] as a project name among [existing], or null when it
/// is fine. [exceptId] is the project being renamed, whose own name is allowed.
ProjectNameProblem? checkProjectName(String name, Iterable<Project> existing, {String? exceptId}) {
  final clean = name.trim();
  if (clean.isEmpty) return ProjectNameProblem.empty;
  if (clean.length > maxProjectNameLength) return ProjectNameProblem.tooLong;
  final taken = existing.any((p) => p.id != exceptId && p.name.toLowerCase() == clean.toLowerCase());
  return taken ? ProjectNameProblem.duplicate : null;
}
