import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../engine/models/models.dart';
import '../../l10n/l10n.dart';
import '../collections/collections_provider.dart';
import '../collections/sidebar_tree.dart' show expandedGroupIdsProvider;
import 'request_draft_provider.dart';

/// Saves the unsaved draft (a pasted curl, say) into a folder: asks which one --
/// or lets the user name a new one -- then adds it to the collections and loads
/// the saved copy, so from then on Save updates it in place.
Future<void> saveDraftToFolder(BuildContext context, WidgetRef ref) async {
  final collections = await ref.read(collectionsProvider.future);
  if (!context.mounted) return;

  final choice = await showDialog<_FolderChoice>(
    context: context,
    builder: (context) => _SaveDraftDialog(groups: collections.groups),
  );
  if (choice == null) return;

  final notifier = ref.read(collectionsProvider.notifier);
  final groupId = choice.groupId ?? (await notifier.createGroup(choice.newFolderName!)).id;

  final saved = ref.read(requestDraftProvider).copyWith(id: const Uuid().v4(), groupId: groupId);
  await notifier.createEndpoint(saved);
  ref.read(requestDraftProvider.notifier).loadEndpoint(saved);
  // The folder holding it opens, or the saved request would be hidden.
  ref.read(expandedGroupIdsProvider.notifier).update((ids) => {...ids, groupId});
}

class _FolderChoice {
  const _FolderChoice.existing(String this.groupId) : newFolderName = null;
  const _FolderChoice.created(String this.newFolderName) : groupId = null;

  final String? groupId;
  final String? newFolderName;
}

const _newFolderValue = '\u0000new';

class _SaveDraftDialog extends StatefulWidget {
  const _SaveDraftDialog({required this.groups});

  final List<Group> groups;

  @override
  State<_SaveDraftDialog> createState() => _SaveDraftDialogState();
}

class _SaveDraftDialogState extends State<_SaveDraftDialog> {
  final _newFolder = TextEditingController();
  late String _selected = widget.groups.isEmpty ? _newFolderValue : _pathsById.keys.first;

  /// Every folder with its full path (`Parent / Child`), in tree order.
  late final Map<String, String> _pathsById = () {
    final byParent = <String?, List<Group>>{};
    for (final g in widget.groups) {
      byParent.putIfAbsent(g.parentGroupId, () => []).add(g);
    }
    final result = <String, String>{};
    void walk(String? parentId, String prefix) {
      final children = [...?byParent[parentId]]..sort((a, b) => a.order.compareTo(b.order));
      for (final g in children) {
        final path = '$prefix${g.name}';
        result[g.id] = path;
        walk(g.id, '$path / ');
      }
    }

    walk(null, '');
    return result;
  }();

  bool get _creating => _selected == _newFolderValue;

  bool get _valid => !_creating || _newFolder.text.trim().isNotEmpty;

  void _submit() {
    if (!_valid) return;
    Navigator.of(context).pop(
      _creating ? _FolderChoice.created(_newFolder.text.trim()) : _FolderChoice.existing(_selected),
    );
  }

  @override
  void dispose() {
    _newFolder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.saveRequestTitle),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: const Key('save-draft-folder-dropdown'),
              initialValue: _selected,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.saveRequestFolderLabel),
              items: [
                for (final entry in _pathsById.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: _newFolderValue, child: Text(l10n.saveRequestNewFolder)),
              ],
              onChanged: (value) => setState(() => _selected = value ?? _selected),
            ),
            if (_creating) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('save-draft-new-folder-field'),
                controller: _newFolder,
                autofocus: true,
                decoration: InputDecoration(hintText: l10n.saveRequestNewFolderHint),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        FilledButton(
          key: const Key('confirm-save-draft-button'),
          onPressed: _valid ? _submit : null,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
