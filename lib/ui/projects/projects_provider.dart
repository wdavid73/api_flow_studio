import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/projects/project.dart';
import '../../engine/projects/projects_repository.dart';
import '../../engine/storage/json_store.dart';

/// The projects and which one is active, together with the store that holds the
/// active project's data.
class ProjectsState {
  const ProjectsState({required this.projects, required this.active, required this.store});

  /// One project over [store], for when projects are not configured (tests, and
  /// anything that supplies its own store).
  factory ProjectsState.single(JsonStore store) {
    final project = Project(id: 'default', name: 'Default', createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    return ProjectsState(projects: [project], active: project, store: store);
  }

  final List<Project> projects;
  final Project active;
  final JsonStore store;
}

/// The repository of projects. Null (the default) means projects are not
/// configured: the app runs as a single project and the list cannot change.
/// `main` overrides it with the real one.
final projectsRepositoryProvider = Provider<ProjectsRepository?>((ref) => null);

/// The state the app starts with. `main` loads it from the repository (after
/// migrating old data) and overrides this; the default is a single project over
/// the default store.
final initialProjectsStateProvider = Provider<ProjectsState>((ref) => ProjectsState.single(JsonStore()));

class ProjectsController extends Notifier<ProjectsState> {
  /// Reads the projects and the active one's store from [repository]. The
  /// repository must already have at least one project (see
  /// `ProjectsRepository.ensureDefaultProject`).
  static Future<ProjectsState> load(ProjectsRepository repository) async {
    final projects = await repository.projects();
    final active = await repository.activeProject();
    if (active == null) throw StateError('The repository has no projects.');
    return ProjectsState(projects: projects, active: active, store: await repository.storeFor(active.id));
  }

  @override
  ProjectsState build() => ref.read(initialProjectsStateProvider);

  ProjectsRepository get _repository {
    final repository = ref.read(projectsRepositoryProvider);
    if (repository == null) throw StateError('Projects are not configured.');
    return repository;
  }

  Future<void> _reload() async => state = await load(_repository);

  Future<void> switchTo(String id) async {
    await _repository.setActive(id);
    await _reload();
  }

  /// Creates a project and makes it the active one.
  Future<Project> create(String name, {int colorIndex = 0}) async {
    final project = await _repository.create(name, colorIndex: colorIndex);
    await _repository.setActive(project.id);
    await _reload();
    return project;
  }

  Future<void> rename(String id, String name) async {
    await _repository.rename(id, name);
    await _reload();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    await _reload();
  }
}

final projectsProvider = NotifierProvider<ProjectsController, ProjectsState>(ProjectsController.new);

/// The id of the active project. Providers that hold state which must not
/// survive a change of project watch this, so they start over when it changes.
final activeProjectIdProvider = Provider<String>(
  (ref) => ref.watch(projectsProvider.select((state) => state.active.id)),
);
