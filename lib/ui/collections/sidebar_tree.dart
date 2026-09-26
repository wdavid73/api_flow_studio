import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../engine/models/models.dart';
import '../request_builder/request_draft_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/widgets/method_badge.dart';
import 'collections_provider.dart';

/// Local UI-only state (not persisted, per SPEC 3.5's own acceptance
/// criteria): which folders are expanded, and the current search text.
final expandedGroupIdsProvider = StateProvider<Set<String>>((ref) => {});
final sidebarSearchQueryProvider = StateProvider<String>((ref) => '');

/// The left sidebar: collapsible collection tree (folders + method-badged
/// endpoint rows), a search box, and actions to create a folder or add a
/// request directly inside one. Selecting an endpoint loads it into the
/// request builder draft (2.4); it isn't saved back until Send/Save.
class SidebarTree extends ConsumerWidget {
  const SidebarTree({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(collectionsProvider);

    return asyncState.when(
      data: (state) => _Loaded(state: state),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Failed to load collections: $error')),
    );
  }
}

class _Loaded extends ConsumerWidget {
  const _Loaded({required this.state});

  final CollectionsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(sidebarSearchQueryProvider).trim().toLowerCase();
    final tree = buildGroupTree(state.groups, state.endpoints);
    final filtered = query.isEmpty ? tree : _filterTree(tree, query);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: TextField(
            key: const Key('sidebar-search-field'),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Filter requests…',
              prefixIcon: Icon(Icons.search, size: 16),
            ),
            onChanged: (value) => ref.read(sidebarSearchQueryProvider.notifier).state = value,
          ),
        ),
        Expanded(
          child: state.groups.isEmpty
              ? const Center(
                  key: Key('empty-workspace-state'),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('No endpoints yet — create a folder to get started.'),
                  ),
                )
              : ListView(
                  children: [for (final node in filtered) _FolderNode(node: node, depth: 0)],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: TextButton.icon(
            key: const Key('new-root-folder-button'),
            onPressed: () => _promptNewFolder(context, ref, parentGroupId: null),
            icon: const Icon(Icons.create_new_folder_outlined, size: 16),
            label: const Text('New folder'),
          ),
        ),
      ],
    );
  }

  List<GroupTreeNode> _filterTree(List<GroupTreeNode> nodes, String query) {
    final result = <GroupTreeNode>[];
    for (final node in nodes) {
      final matchingEndpoints = node.endpoints
          .where((e) => e.name.toLowerCase().contains(query) || e.url.toLowerCase().contains(query))
          .toList();
      final filteredChildren = _filterTree(node.children, query);
      if (matchingEndpoints.isNotEmpty || filteredChildren.isNotEmpty) {
        result.add(GroupTreeNode(
          group: node.group,
          children: filteredChildren,
          endpoints: matchingEndpoints,
        ));
      }
    }
    return result;
  }
}

Future<void> _promptNewFolder(
  BuildContext context,
  WidgetRef ref, {
  required String? parentGroupId,
}) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('New folder'),
      content: TextField(
        key: const Key('new-folder-name-field'),
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Folder name'),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(
          key: const Key('confirm-new-folder-button'),
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Create'),
        ),
      ],
    ),
  );
  if (name != null && name.trim().isNotEmpty) {
    await ref.read(collectionsProvider.notifier).createGroup(name.trim(), parentGroupId: parentGroupId);
  }
}

class _FolderNode extends ConsumerWidget {
  const _FolderNode({required this.node, required this.depth});

  final GroupTreeNode node;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedIds = ref.watch(expandedGroupIdsProvider);
    final isExpanded = expandedIds.contains(node.group.id);
    final indent = EdgeInsets.only(left: AppSpacing.md * depth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: indent,
          child: Row(
            children: [
              IconButton(
                key: ValueKey('toggle-group-${node.group.id}'),
                icon: Icon(isExpanded ? Icons.expand_more : Icons.chevron_right, size: 16),
                onPressed: () {
                  final next = {...expandedIds};
                  if (isExpanded) {
                    next.remove(node.group.id);
                  } else {
                    next.add(node.group.id);
                  }
                  ref.read(expandedGroupIdsProvider.notifier).state = next;
                },
              ),
              Expanded(child: Text(node.group.name, overflow: TextOverflow.ellipsis)),
              IconButton(
                key: ValueKey('add-endpoint-${node.group.id}'),
                tooltip: 'Add request',
                icon: const Icon(Icons.add, size: 16),
                onPressed: () async {
                  final endpoint = Endpoint(
                    id: const Uuid().v4(),
                    groupId: node.group.id,
                    name: 'New Request',
                    method: 'GET',
                    url: '',
                  );
                  await ref.read(collectionsProvider.notifier).createEndpoint(endpoint);
                  ref.read(requestDraftProvider.notifier).loadEndpoint(endpoint);
                },
              ),
            ],
          ),
        ),
        if (isExpanded) ...[
          for (final child in node.children) _FolderNode(node: child, depth: depth + 1),
          for (final endpoint in node.endpoints)
            _EndpointRow(endpoint: endpoint, depth: depth + 1),
          if (node.children.isEmpty && node.endpoints.isEmpty)
            Padding(
              padding: indent.add(const EdgeInsets.only(left: AppSpacing.lg)),
              child: const Text('No endpoints yet — + Add request', key: Key('empty-folder-state')),
            ),
        ],
      ],
    );
  }
}

class _EndpointRow extends ConsumerWidget {
  const _EndpointRow({required this.endpoint, required this.depth});

  final Endpoint endpoint;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.only(left: AppSpacing.md * depth + AppSpacing.lg),
      child: InkWell(
        key: ValueKey('endpoint-row-${endpoint.id}'),
        onTap: () => ref.read(requestDraftProvider.notifier).loadEndpoint(endpoint),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              MethodBadge(method: endpoint.method),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(endpoint.name, overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }
}
