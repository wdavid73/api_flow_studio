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
  // Every mutation runs through this queue, one at a time: two calls fired
  // back-to-back (e.g. two fast keystrokes, each triggering a save) must
  // each see the *other's* result, not a snapshot from before either ran.
  // `await future` alone doesn't guarantee that -- it resolves with
  // whatever `state` already is at the moment it's read, so a second call
  // starting before the first has finished assigning `state` would still
  // read the pre-mutation value. Chaining onto `_queue` forces call N to
  // fully finish (including its `state = ...` assignment) before call N+1
  // even starts building its own next state.
  Future<void> _queue = Future.value();

  Future<T> _mutate<T>(Future<T> Function(EnvironmentsState current) action) {
    final result = _queue.then((_) async {
      final current = await future;
      return action(current);
    });
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<EnvironmentsState> build() async {
    final store = ref.read(jsonStoreProvider);
    final environments = await store.readEnvironments();
    final activeId = await store.readActiveEnvironmentId();
    return EnvironmentsState(environments: environments, activeEnvironmentId: activeId);
  }

  Future<void> create(String name) => _mutate((current) async {
        final next = [...current.environments, Environment(id: const Uuid().v4(), name: name)];
        state = AsyncData(current.copyWith(environments: next));
        await ref.read(jsonStoreProvider).writeEnvironments(next);
      });

  Future<void> updateEnvironment(Environment environment) => _mutate((current) async {
        final next = [
          for (final e in current.environments) if (e.id == environment.id) environment else e,
        ];
        state = AsyncData(current.copyWith(environments: next));
        await ref.read(jsonStoreProvider).writeEnvironments(next);
      });

  Future<void> duplicate(String id) => _mutate((current) async {
        final source = current.environments.firstWhere((e) => e.id == id);
        final next = [
          ...current.environments,
          source.copyWith(id: const Uuid().v4(), name: '${source.name} Copy'),
        ];
        state = AsyncData(current.copyWith(environments: next));
        await ref.read(jsonStoreProvider).writeEnvironments(next);
      });

  Future<void> delete(String id) => _mutate((current) async {
        final next = current.environments.where((e) => e.id != id).toList();
        final newActiveId = current.activeEnvironmentId == id ? null : current.activeEnvironmentId;
        state = AsyncData(EnvironmentsState(environments: next, activeEnvironmentId: newActiveId));
        final store = ref.read(jsonStoreProvider);
        await store.writeEnvironments(next);
        if (newActiveId != current.activeEnvironmentId) {
          await store.writeActiveEnvironmentId(newActiveId);
        }
      });

  Future<void> setActive(String? id) => _mutate((current) async {
        state =
            AsyncData(EnvironmentsState(environments: current.environments, activeEnvironmentId: id));
        await ref.read(jsonStoreProvider).writeActiveEnvironmentId(id);
      });
}

final environmentsProvider = AsyncNotifierProvider<EnvironmentsNotifier, EnvironmentsState>(
  EnvironmentsNotifier.new,
);
