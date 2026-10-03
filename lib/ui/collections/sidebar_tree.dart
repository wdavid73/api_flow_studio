import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../engine/models/models.dart';
import '../request_builder/request_draft_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/widgets/method_badge.dart';
import 'collections_provider.dart';
import 'endpoint_filter.dart';
import 'method_filter_chips.dart';
import 'paste_curl_dialog.dart';
import '../projects/projects_provider.dart';

/// The real app version, shown in the sidebar footer in place of the
/// design mockup's fake "Proxy: Localhost" line -- kept in sync with
/// pubspec.yaml's `version:` by hand (no packages read it at runtime).
const _appVersion = 'v1.0.0';

/// Shrinks the sidebar header's icon buttons from Material's default 48x48
/// tap target down to their padded icon size -- with four of them (folder,
/// paste curl, import, export) sharing a ~266px-wide header, the default
/// size overflows the row.
final _headerIconButtonStyle = IconButton.styleFrom(
  padding: const EdgeInsets.all(AppSpacing.xs),
  minimumSize: Size.zero,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

/// Local UI-only state (not persisted, per SPEC 3.5's own acceptance
/// criteria): which folders are expanded, and the current search text.
final expandedGroupIdsProvider = StateProvider<Set<String>>((ref) {
  ref.watch(activeProjectIdProvider); // folder ids belong to one project
  return {};
});
final sidebarSearchQueryProvider = StateProvider<String>((ref) {
  ref.watch(activeProjectIdProvider);
  return '';
});

/// Focus node of the search field, so the `/` shortcut can focus it.
final sidebarSearchFocusNodeProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'sidebar-search');
  ref.onDispose(node.dispose);
  return node;
});

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
    final method = ref.watch(sidebarMethodFilterProvider);
    final filtered = filterTree(tree, query: query, method: method);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.xs),
          child: Row(
            children: [
              Text(
                'EXPLORER',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              IconButton(
                key: const Key('new-root-folder-button'),
                tooltip: 'New folder',
                style: _headerIconButtonStyle,
                icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                onPressed: () => _promptNewFolder(context, ref, parentGroupId: null),
              ),
              IconButton(
                key: const Key('paste-curl-button'),
                tooltip: 'Paste curl',
                style: _headerIconButtonStyle,
                icon: const Icon(Icons.content_paste, size: 16),
                onPressed: () => showPasteCurlDialog(context),
              ),
              IconButton(
                key: const Key('import-collections-button'),
                tooltip: 'Import endpoints (JSON)',
                style: _headerIconButtonStyle,
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                onPressed: () => _importCollections(context, ref),
              ),
              IconButton(
                key: const Key('export-collections-button'),
                tooltip: 'Export endpoints (JSON)',
                style: _headerIconButtonStyle,
                icon: const Icon(Icons.file_download_outlined, size: 16),
                onPressed: () => _exportCollections(context, ref, state),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: TextField(
            key: const Key('sidebar-search-field'),
            focusNode: ref.watch(sidebarSearchFocusNodeProvider),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Filter requests…',
              prefixIcon: Icon(Icons.search, size: 16),
            ),
            onChanged: (value) => ref.read(sidebarSearchQueryProvider.notifier).state = value,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: MethodFilterChips(),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: state.groups.isEmpty
              ? const Center(
                  key: Key('empty-workspace-state'),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text('No endpoints yet — create a folder to get started.'),
                  ),
                )
              : filtered.isEmpty
                  ? Center(
                      key: const Key('no-results-state'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          'Nothing matches that search.',
                          style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final (index, node) in filtered.indexed)
                          _FolderNode(node: node, depth: 0, colorIndex: index),
                      ],
                    ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          color: AppColors.surfaceContainerLowest,
          child: Text(
            'API Flow Studio $_appVersion',
            style: AppTypography.codeSm.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Opens a native "Open file" dialog, parses the picked file as a
/// `{groups, endpoints}` collections JSON (same shape [JsonStore] persists
/// to `collections.json`), and merges it into the current workspace via
/// [CollectionsNotifier.importCollections]. Cancelling the dialog is a
/// silent no-op; a file that isn't valid JSON in the expected shape shows
/// an error instead of touching existing data.
Future<void> _importCollections(BuildContext context, WidgetRef ref) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    dialogTitle: 'Import endpoints',
  );
  final path = result?.files.single.path;
  if (path == null) return;

  try {
    final decoded = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    final groups = ((decoded['groups'] as List?) ?? const [])
        .map((e) => Group.fromJson(e as Map<String, dynamic>))
        .toList();
    final endpoints = ((decoded['endpoints'] as List?) ?? const [])
        .map((e) => Endpoint.fromJson(e as Map<String, dynamic>))
        .toList();

    final counts = await ref
        .read(collectionsProvider.notifier)
        .importCollections(groups: groups, endpoints: endpoints);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Imported ${counts.groupCount} folder(s) and ${counts.endpointCount} endpoint(s).',
        ),
      ));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not import file: not a valid endpoints JSON.'),
      ));
    }
  }
}

/// Opens a native "Save file" dialog and writes the current workspace's
/// groups/endpoints to it in the same shape [JsonStore] uses for
/// `collections.json`, so the result can later be picked back up by
/// [_importCollections] (on this machine or another one).
Future<void> _exportCollections(
  BuildContext context,
  WidgetRef ref,
  CollectionsState state,
) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Export endpoints',
    fileName: 'api-flow-studio-endpoints.json',
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (path == null) return;

  final json = const JsonEncoder.withIndent('  ').convert({
    'groups': state.groups.map((g) => g.toJson()).toList(),
    'endpoints': state.endpoints.map((e) => e.toJson()).toList(),
  });
  await File(path).writeAsString(json);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported to $path')));
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
  const _FolderNode({required this.node, required this.depth, required this.colorIndex});

  final GroupTreeNode node;
  final int depth;
  final int colorIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expandedIds = ref.watch(expandedGroupIdsProvider);
    // While any filter is active, show every folder that survived it open:
    // otherwise a match inside a collapsed folder would stay hidden.
    final filtering = ref.watch(sidebarSearchQueryProvider).trim().isNotEmpty ||
        ref.watch(sidebarMethodFilterProvider) != allMethods;
    final isExpanded = filtering || expandedIds.contains(node.group.id);
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
              Icon(Icons.folder, size: 16, color: AppColors.folderIconColor(colorIndex)),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        node.group.name,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    if (depth == 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${_endpointCount(node)}',
                        key: ValueKey('group-count-${node.group.id}'),
                        style: AppTypography.codeSm.copyWith(color: AppColors.outline),
                      ),
                    ],
                  ],
                ),
              ),
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
              IconButton(
                key: ValueKey('delete-group-${node.group.id}'),
                tooltip: 'Delete folder',
                icon: const Icon(Icons.delete_outline, size: 16),
                onPressed: () async {
                  try {
                    await ref.read(collectionsProvider.notifier).deleteGroup(node.group.id);
                  } on GroupNotEmptyException {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Delete this folder\'s contents first.'),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
        if (isExpanded) ...[
          for (final (index, child) in node.children.indexed)
            _FolderNode(node: child, depth: depth + 1, colorIndex: index),
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

/// Endpoints in [node] and all its descendant folders.
int _endpointCount(GroupTreeNode node) =>
    node.endpoints.length + node.children.fold(0, (sum, child) => sum + _endpointCount(child));

class _EndpointRow extends ConsumerWidget {
  const _EndpointRow({required this.endpoint, required this.depth});

  final Endpoint endpoint;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(requestDraftProvider.select((d) => d.id == endpoint.id));

    return Padding(
      padding: EdgeInsets.only(left: AppSpacing.md * depth + AppSpacing.lg, right: AppSpacing.xs),
      child: Material(
        key: ValueKey('endpoint-surface-${endpoint.id}'),
        color: selected ? AppColors.surfaceContainerHigh : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: InkWell(
          key: ValueKey('endpoint-row-${endpoint.id}'),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          hoverColor: AppColors.surfaceContainer,
          onTap: () => ref.read(requestDraftProvider.notifier).loadEndpoint(endpoint),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            child: Row(
              children: [
                SizedBox(
                  key: Key('endpoint-method-${endpoint.id}'),
                  width: 54,
                  child: MethodBadge(method: endpoint.method),
                ),
                Expanded(
                  child: Text(
                    endpoint.name,
                    key: Key('endpoint-name-${endpoint.id}'),
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.codeMd,
                  ),
                ),
                IconButton(
                  key: ValueKey('delete-endpoint-${endpoint.id}'),
                  tooltip: 'Delete request',
                  icon: const Icon(Icons.delete_outline, size: 14),
                  onPressed: () => ref.read(collectionsProvider.notifier).deleteEndpoint(endpoint.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
