import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../projects/project.dart';
import '../projects/projects_repository.dart';
import 'workspace_file.dart';

/// What importing a workspace produced.
class ImportedWorkspace {
  const ImportedWorkspace({required this.project, required this.secretsToFill});

  /// The project that was created.
  final Project project;

  /// How many secret values the person still has to type in.
  final int secretsToFill;
}

/// Reads [text] as a workspace file and imports it. A file that is not a valid
/// workspace throws a [WorkspaceFileException] before anything is created.
Future<ImportedWorkspace> importWorkspaceText(
  ProjectsRepository repository,
  String text, {
  bool activate = false,
}) async =>
    importWorkspace(repository, WorkspaceFile.parse(text), activate: activate);

/// Creates a **new** project from [file]; it never touches an existing one.
///
/// The name is made unique (`commodo`, `commodo (2)`, ...) and every id is
/// regenerated, with the links between environments, folders, requests and flow
/// steps following the new ids. No environment is made active: the person picks
/// one, so nothing starts pointing at production by accident. If writing the data
/// fails, the half-made project is removed and the error is raised.
Future<ImportedWorkspace> importWorkspace(
  ProjectsRepository repository,
  WorkspaceFile file, {
  bool activate = false,
}) async {
  final taken = await repository.projects();
  final project = await repository.create(_uniqueName(file.name, taken), colorIndex: file.colorIndex);

  try {
    final store = await repository.storeFor(project.id);
    final data = _withNewIds(file);
    await store.writeEnvironments(data.environments);
    await store.writeCollections(groups: data.groups, endpoints: data.endpoints);
    await store.writeFlows(data.flows);
    await store.writeHostNotes(file.hostNotes);
    if (activate) await repository.setActive(project.id);
  } catch (_) {
    try {
      await repository.delete(project.id);
    } on LastProjectException {
      // Nothing else to fall back to: leave it rather than leave no project.
    }
    rethrow;
  }
  return ImportedWorkspace(project: project, secretsToFill: file.secretsToFill);
}

/// [name] shortened to the limit and, when another project has it, numbered.
String _uniqueName(String name, List<Project> taken) {
  final base = name.trim().length > maxProjectNameLength ? name.trim().substring(0, maxProjectNameLength).trim() : name.trim();
  if (checkProjectName(base, taken) == null) return base;

  for (var n = 2;; n++) {
    final suffix = ' ($n)';
    final room = maxProjectNameLength - suffix.length;
    final candidate = '${base.length > room ? base.substring(0, room).trim() : base}$suffix';
    if (checkProjectName(candidate, taken) == null) return candidate;
  }
}

typedef _Data = ({
  List<Environment> environments,
  List<Group> groups,
  List<Endpoint> endpoints,
  List<Flow> flows,
});

/// The content of [file] with fresh ids everywhere and every reference remapped.
/// A reference to something the file does not contain is left as it was.
_Data _withNewIds(WorkspaceFile file) {
  const uuid = Uuid();
  final groupIds = <String, String>{};
  final endpointIds = <String, String>{};

  // Two items with the same id (a damaged file) still get their own new id; the
  // links go to the first.
  final groups = [
    for (final g in file.groups)
      () {
        final id = uuid.v4();
        groupIds.putIfAbsent(g.id, () => id);
        return g.copyWith(id: id);
      }(),
  ];
  final endpoints = [
    for (final e in file.endpoints)
      () {
        final id = uuid.v4();
        endpointIds.putIfAbsent(e.id, () => id);
        return e.copyWith(id: id);
      }(),
  ];

  return (
    environments: [for (final env in file.environments) env.copyWith(id: uuid.v4())],
    groups: [
      for (final g in groups)
        // A parent the file does not contain would never be shown: make it a top-level folder.
        g.copyWith(parentGroupId: g.parentGroupId == null ? null : groupIds[g.parentGroupId]),
    ],
    endpoints: [
      for (final e in endpoints) e.copyWith(groupId: groupIds[e.groupId] ?? e.groupId),
    ],
    flows: [
      for (final f in file.flows)
        f.copyWith(
          id: uuid.v4(),
          steps: [for (final s in f.steps) s.copyWith(endpointId: endpointIds[s.endpointId] ?? s.endpointId)],
        ),
    ],
  );
}
