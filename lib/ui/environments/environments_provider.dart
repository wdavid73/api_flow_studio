import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../engine/models/models.dart';
import '../../engine/storage/json_store.dart';

/// Overridden in tests with a temp-directory [JsonStore]; the real app uses
/// the default OS-app-data-backed instance.
final jsonStoreProvider = Provider<JsonStore>((ref) => JsonStore());

class EnvironmentsState {
  const EnvironmentsState({this.environments = const [], this.activeEnvironmentId});

  final List<Environment> environments;
  final String? activeEnvironmentId;

  Environment? get active => environments.where((e) => e.id == activeEnvironmentId).firstOrNull;

  EnvironmentsState copyWith({List<Environment>? environments}) => EnvironmentsState(
        environments: environments ?? this.environments,
        activeEnvironmentId: activeEnvironmentId,
      );
}

/// CRUD over the environments list plus which one is active, persisted to
/// disk (via [JsonStore]) on every mutation.
class EnvironmentsNotifier extends AsyncNotifier<EnvironmentsState> {
  @override
  Future<EnvironmentsState> build() async {
    final store = ref.read(jsonStoreProvider);
    final environments = await store.readEnvironments();
    final activeId = await store.readActiveEnvironmentId();
    return EnvironmentsState(environments: environments, activeEnvironmentId: activeId);
  }

  Future<void> create(String name) async {
    final current = await future;
    final next = [...current.environments, Environment(id: const Uuid().v4(), name: name)];
    await ref.read(jsonStoreProvider).writeEnvironments(next);
    state = AsyncData(current.copyWith(environments: next));
  }

  Future<void> updateEnvironment(Environment environment) async {
    final current = await future;
    final next = [
      for (final e in current.environments) if (e.id == environment.id) environment else e,
    ];
    await ref.read(jsonStoreProvider).writeEnvironments(next);
    state = AsyncData(current.copyWith(environments: next));
  }

  Future<void> duplicate(String id) async {
    final current = await future;
    final source = current.environments.firstWhere((e) => e.id == id);
    final next = [
      ...current.environments,
      source.copyWith(id: const Uuid().v4(), name: '${source.name} Copy'),
    ];
    await ref.read(jsonStoreProvider).writeEnvironments(next);
    state = AsyncData(current.copyWith(environments: next));
  }

  Future<void> delete(String id) async {
    final current = await future;
    final next = current.environments.where((e) => e.id != id).toList();
    final newActiveId = current.activeEnvironmentId == id ? null : current.activeEnvironmentId;
    final store = ref.read(jsonStoreProvider);
    await store.writeEnvironments(next);
    if (newActiveId != current.activeEnvironmentId) {
      await store.writeActiveEnvironmentId(newActiveId);
    }
    state = AsyncData(EnvironmentsState(environments: next, activeEnvironmentId: newActiveId));
  }

  Future<void> setActive(String? id) async {
    final current = await future;
    await ref.read(jsonStoreProvider).writeActiveEnvironmentId(id);
    state = AsyncData(EnvironmentsState(environments: current.environments, activeEnvironmentId: id));
  }
}

final environmentsProvider = AsyncNotifierProvider<EnvironmentsNotifier, EnvironmentsState>(
  EnvironmentsNotifier.new,
);
