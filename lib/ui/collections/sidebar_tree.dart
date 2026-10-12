import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../engine/models/models.dart';
import '../import/import_actions.dart';
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
import '../../l10n/l10n.dart';
import '../files/file_download.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
      error: (error, stack) => Center(child: Text(context.l10n.commonFailedToLoad(context.l10n.collectionsLoadWhat, error))),
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
                context.l10n.collectionsKicker,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              IconButton(
                key: const Key('new-root-folder-button'),
                tooltip: context.l10n.collectionsNewFolder,
                style: _headerIconButtonStyle,
                icon: const Icon(Icons.create_new_folder_outlined, size: 16),
                onPressed: () => _promptNewFolder(context, ref, parentGroupId: null),
              ),
              IconButton(
                key: const Key('paste-curl-button'),
                tooltip: context.l10n.collectionsPasteCurl,
                style: _headerIconButtonStyle,
                icon: const Icon(Icons.content_paste, size: 16),
                onPressed: () => showPasteCurlDialog(context),
              ),
              IconButton(
                key: const Key('import-collections-button'),
                tooltip: context.l10n.collectionsImportEllipsis,
                style: _headerIconButtonStyle,
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                onPressed: () => importFile(context, ref),
              ),
              IconButton(
                key: const Key('export-collections-button'),
                tooltip: context.l10n.collectionsExportTooltip,
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
            decoration: InputDecoration(
              isDense: true,
              hintText: context.l10n.collectionsFilterHint,
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
              ? Center(
                  key: Key('empty-workspace-state'),
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Text(context.l10n.collectionsEmpty),
                  ),
                )
              : filtered.isEmpty
                  ? Center(
                      key: const Key('no-results-state'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Text(
                          context.l10n.commonNothingMatches,
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
            context.l10n.collectionsVersion(_appVersion),
            style: AppTypography.codeSm.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// Opens a native "Save file" dialog and writes the current workspace's
/// groups/endpoints to it in the same shape [JsonStore] uses for
/// `collections.json`, so the result can later be picked back up by
/// the Import button (on this machine or another one).
Future<void> _exportCollections(
  BuildContext context,
  WidgetRef ref,
  CollectionsState state,
) async {
  final l10n = context.l10n;
  final json = const JsonEncoder.withIndent('  ').convert({
    'groups': state.groups.map((g) => g.toJson()).toList(),
    'endpoints': state.endpoints.map((e) => e.toJson()).toList(),
  });

  if (kIsWeb) {
    const fileName = 'api-flow-studio-endpoints.json';
    await downloadTextFile(fileName, json);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.collectionsExportedTo(fileName))));
    }
    return;
  }

  final path = await FilePicker.platform.saveFile(
    dialogTitle: l10n.collectionsExportTitle,
    fileName: 'api-flow-studio-endpoints.json',
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (path == null) return;

  await File(path).writeAsString(json);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.collectionsExportedTo(path))));
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
      title: Text(context.l10n.collectionsNewFolder),
      content: TextField(
        key: const Key('new-folder-name-field'),
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: context.l10n.collectionsFolderName),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.commonCancel)),
        TextButton(
          key: const Key('confirm-new-folder-button'),
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: Text(context.l10n.commonCreate),
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
                tooltip: context.l10n.collectionsAddRequest,
                icon: const Icon(Icons.add, size: 16),
                onPressed: () async {
                  final endpoint = Endpoint(
                    id: const Uuid().v4(),
                    groupId: node.group.id,
                    name: context.l10n.collectionsNewRequestName,
                    method: 'GET',
                    url: '',
                  );
                  await ref.read(collectionsProvider.notifier).createEndpoint(endpoint);
                  ref.read(requestDraftProvider.notifier).loadEndpoint(endpoint);
                },
              ),
              IconButton(
                key: ValueKey('delete-group-${node.group.id}'),
                tooltip: context.l10n.collectionsDeleteFolder,
                icon: const Icon(Icons.delete_outline, size: 16),
                onPressed: () async {
                  try {
                    await ref.read(collectionsProvider.notifier).deleteGroup(node.group.id);
                  } on GroupNotEmptyException {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.collectionsDeleteFolderFirst),
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
              child: Text(context.l10n.collectionsEmptyFolder, key: const Key('empty-folder-state')),
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
                  tooltip: context.l10n.collectionsDeleteRequest,
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
