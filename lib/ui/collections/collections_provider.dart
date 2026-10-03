import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../engine/models/models.dart';
import '../../engine/storage/json_store.dart';
import '../environments/environments_provider.dart' show jsonStoreProvider;

class CollectionsState {
  const CollectionsState({this.groups = const [], this.endpoints = const []});

  final List<Group> groups;
  final List<Endpoint> endpoints;

  CollectionsState copyWith({List<Group>? groups, List<Endpoint>? endpoints}) => CollectionsState(
        groups: groups ?? this.groups,
        endpoints: endpoints ?? this.endpoints,
      );
}

/// A group and its nested children/endpoints, reconstructed from the flat
/// `groups[]`/`endpoints[]` lists [JsonStore] persists (see [buildGroupTree]).
class GroupTreeNode {
  const GroupTreeNode({required this.group, required this.children, required this.endpoints});

  final Group group;
  final List<GroupTreeNode> children;
  final List<Endpoint> endpoints;
}

/// Turns the flat, on-disk group/endpoint lists into a nested tree for the
/// sidebar, ordered by each [Group.order] within its parent.
List<GroupTreeNode> buildGroupTree(List<Group> groups, List<Endpoint> endpoints) {
  List<Group> childrenOf(String? parentId) =>
      groups.where((g) => g.parentGroupId == parentId).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  GroupTreeNode buildNode(Group group) => GroupTreeNode(
        group: group,
        children: [for (final child in childrenOf(group.id)) buildNode(child)],
        endpoints: endpoints.where((e) => e.groupId == group.id).toList(),
      );

  return [for (final root in childrenOf(null)) buildNode(root)];
}

/// Merges [importedGroups]/[importedEndpoints] (parsed from a JSON file
/// picked via the Import button) into [current]. Every imported group and
/// endpoint gets a freshly generated id, with `parentGroupId`/`groupId`
/// references remapped to match -- so importing a file exported from
/// another machine (or the repo's sample file) can never collide with or
/// overwrite anything already in the workspace. Imported root groups are
/// ordered after the existing root groups, preserving their relative order
/// from the file; an endpoint whose `groupId` isn't among the imported
/// groups is dropped rather than left pointing at nothing.
CollectionsState mergeImportedCollections(
  CollectionsState current, {
  required List<Group> importedGroups,
  required List<Endpoint> importedEndpoints,
}) {
  const uuid = Uuid();
  final idMap = {for (final g in importedGroups) g.id: uuid.v4()};
  final existingRootCount = current.groups.where((g) => g.parentGroupId == null).length;

  final newGroups = [
    for (final g in importedGroups)
      g.copyWith(
        id: idMap[g.id]!,
        parentGroupId: g.parentGroupId == null ? null : idMap[g.parentGroupId],
        order: g.parentGroupId == null ? existingRootCount + g.order : g.order,
      ),
  ];

  final newEndpoints = [
    for (final e in importedEndpoints)
      if (idMap[e.groupId] case final newGroupId?) e.copyWith(id: uuid.v4(), groupId: newGroupId),
  ];

  return current.copyWith(
    groups: [...current.groups, ...newGroups],
    endpoints: [...current.endpoints, ...newEndpoints],
  );
}

/// Thrown by [CollectionsNotifier.deleteGroup] when the group still has
/// child groups or endpoints -- deletes are blocked, not cascaded, so a
/// user can't lose a whole subtree with one misclick (matches common IDE
/// file-tree UX).
class GroupNotEmptyException implements Exception {
  const GroupNotEmptyException(this.groupId);

  final String groupId;

  @override
  String toString() => 'Cannot delete group "$groupId": it still has child groups or endpoints.';
}

/// CRUD over groups (nested via [Group.parentGroupId]) and endpoints,
/// persisted to disk on every mutation. Mutations are queued (same pattern
/// as EnvironmentsNotifier, see tasks/plan.md's testing note) so two calls
/// fired close together each build on the other's fully-applied result
/// instead of racing on a stale snapshot.
class CollectionsNotifier extends AsyncNotifier<CollectionsState> {
  Future<void> _queue = Future.value();

  Future<T> _mutate<T>(Future<T> Function(CollectionsState current) action) {
    final result = _queue.then((_) async {
      final current = await future;
      return action(current);
    });
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<CollectionsState> build() async {
    final store = ref.watch(jsonStoreProvider);
    final result = await store.readCollections();
    return CollectionsState(groups: result.groups, endpoints: result.endpoints);
  }

  Future<void> _persist(CollectionsState next) async {
    state = AsyncData(next);
    await ref
        .read(jsonStoreProvider)
        .writeCollections(groups: next.groups, endpoints: next.endpoints);
  }

  Future<Group> createGroup(String name, {String? parentGroupId}) => _mutate((current) async {
        final siblingCount =
            current.groups.where((g) => g.parentGroupId == parentGroupId).length;
        final group = Group(
          id: const Uuid().v4(),
          name: name,
          parentGroupId: parentGroupId,
          order: siblingCount,
        );
        await _persist(current.copyWith(groups: [...current.groups, group]));
        return group;
      });

  Future<void> renameGroup(String id, String name) => _mutate((current) async {
        final next = [
          for (final g in current.groups) if (g.id == id) g.copyWith(name: name) else g,
        ];
        await _persist(current.copyWith(groups: next));
      });

  Future<void> deleteGroup(String id) => _mutate((current) async {
        final hasChildGroups = current.groups.any((g) => g.parentGroupId == id);
        final hasEndpoints = current.endpoints.any((e) => e.groupId == id);
        if (hasChildGroups || hasEndpoints) {
          throw GroupNotEmptyException(id);
        }
        final next = current.groups.where((g) => g.id != id).toList();
        await _persist(current.copyWith(groups: next));
      });

  Future<Endpoint> createEndpoint(Endpoint endpoint) => _mutate((current) async {
        await _persist(current.copyWith(endpoints: [...current.endpoints, endpoint]));
        return endpoint;
      });

  Future<void> updateEndpoint(Endpoint endpoint) => _mutate((current) async {
        final next = [
          for (final e in current.endpoints) if (e.id == endpoint.id) endpoint else e,
        ];
        await _persist(current.copyWith(endpoints: next));
      });

  Future<void> deleteEndpoint(String id) => _mutate((current) async {
        final next = current.endpoints.where((e) => e.id != id).toList();
        await _persist(current.copyWith(endpoints: next));
      });

  Future<void> moveEndpoint(String id, String newGroupId) => _mutate((current) async {
        final next = [
          for (final e in current.endpoints)
            if (e.id == id) e.copyWith(groupId: newGroupId) else e,
        ];
        await _persist(current.copyWith(endpoints: next));
      });

  /// Imports groups/endpoints from another JSON file (see
  /// [mergeImportedCollections]) and returns how many of each were added,
  /// for the caller to report back to the user.
  Future<({int groupCount, int endpointCount})> importCollections({
    required List<Group> groups,
    required List<Endpoint> endpoints,
  }) =>
      _mutate((current) async {
        final merged = mergeImportedCollections(
          current,
          importedGroups: groups,
          importedEndpoints: endpoints,
        );
        await _persist(merged);
        return (groupCount: groups.length, endpointCount: endpoints.length);
      });
}

final collectionsProvider = AsyncNotifierProvider<CollectionsNotifier, CollectionsState>(
  CollectionsNotifier.new,
);
