import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../engine/models/models.dart';
import '../environments/environments_provider.dart' show jsonStoreProvider;

/// CRUD over saved [Flow]s and their [FlowStep]s, persisted to disk on
/// every mutation. Same queued-mutation pattern as EnvironmentsNotifier/
/// CollectionsNotifier (see tasks/plan.md's testing note): each call reads
/// `await future`, mutates, and writes, chained through a per-notifier
/// queue so overlapping calls can't race on a stale snapshot.
class FlowsNotifier extends AsyncNotifier<List<Flow>> {
  Future<void> _queue = Future.value();

  Future<T> _mutate<T>(Future<T> Function(List<Flow> current) action) {
    final result = _queue.then((_) async {
      final current = await future;
      return action(current);
    });
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<List<Flow>> build() => ref.watch(jsonStoreProvider).readFlows();

  Future<void> _persist(List<Flow> next) async {
    state = AsyncData(next);
    await ref.read(jsonStoreProvider).writeFlows(next);
  }

  Future<Flow> createFlow(String name) => _mutate((current) async {
        final flow = Flow(id: const Uuid().v4(), name: name);
        await _persist([...current, flow]);
        return flow;
      });

  Future<void> renameFlow(String flowId, String name) => _mutate((current) async {
        await _persist([
          for (final f in current) if (f.id == flowId) f.copyWith(name: name) else f,
        ]);
      });

  Future<void> deleteFlow(String flowId) => _mutate((current) async {
        await _persist(current.where((f) => f.id != flowId).toList());
      });

  Future<void> addStep(String flowId, FlowStep step) => _mutate((current) async {
        await _persist([
          for (final f in current)
            if (f.id == flowId) f.copyWith(steps: [...f.steps, step]) else f,
        ]);
      });

  Future<void> removeStep(String flowId, int index) => _mutate((current) async {
        await _persist([
          for (final f in current)
            if (f.id == flowId)
              f.copyWith(steps: [...f.steps]..removeAt(index))
            else
              f,
        ]);
      });

  /// Moves the step at [fromIndex] to [toIndex], shifting the others --
  /// simple up/down reordering (no drag-and-drop) is enough for v1.
  Future<void> reorderStep(String flowId, int fromIndex, int toIndex) => _mutate((current) async {
        await _persist([
          for (final f in current)
            if (f.id == flowId) f.copyWith(steps: _moved(f.steps, fromIndex, toIndex)) else f,
        ]);
      });

  List<FlowStep> _moved(List<FlowStep> steps, int fromIndex, int toIndex) {
    final next = [...steps];
    final step = next.removeAt(fromIndex);
    next.insert(toIndex, step);
    return next;
  }

  Future<void> updateStep(String flowId, int index, FlowStep step) => _mutate((current) async {
        await _persist([
          for (final f in current)
            if (f.id == flowId)
              f.copyWith(steps: [
                for (var i = 0; i < f.steps.length; i++) if (i == index) step else f.steps[i],
              ])
            else
              f,
        ]);
      });
}

final flowsProvider = AsyncNotifierProvider<FlowsNotifier, List<Flow>>(FlowsNotifier.new);
