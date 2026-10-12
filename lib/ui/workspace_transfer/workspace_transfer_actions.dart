import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/workspace/export_workspace.dart';
import '../../engine/workspace/workspace_file.dart';
import '../projects/projects_provider.dart';
import '../shell/app_toast.dart';
import 'workspace_file_dialogs.dart';
import '../../l10n/l10n.dart';

/// Saves the active project to a workspace file the person picks.
Future<void> exportActiveProject(WidgetRef ref, AppLocalizations l10n) async {
  final state = ref.read(projectsProvider);
  final dialogs = ref.read(workspaceFileDialogsProvider);

  try {
    final file = await exportWorkspace(state.store, state.active);
    final saved = await dialogs.saveText(workspaceFileName(state.active.name), file.encode());
    if (!saved) return; // cancelled: nothing to say
    showToast(ref, l10n.workspaceExported(state.active.name));
  } catch (error) {
    showToast(ref, l10n.workspaceCouldNotSave(error));
  }
}

/// Imports a workspace file the person picks as a new project and switches to
/// it. A file that cannot be used is explained in a dialog.
Future<void> importWorkspaceFromFile(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final dialogs = ref.read(workspaceFileDialogsProvider);

  final String? text;
  try {
    text = await dialogs.openText();
  } catch (error) {
    showToast(ref, l10n.workspaceCouldNotReadFile(error));
    return;
  }
  if (text == null) return;

  try {
    final imported = await ref.read(projectsProvider.notifier).importWorkspace(text);
    final name = imported.project.name;
    final pending = imported.secretsToFill;
    showToast(
      ref,
      pending == 0 ? l10n.workspaceImported(name) : l10n.workspaceImportedToFill(name, pending),
    );
  } on WorkspaceFileException catch (error) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('import-error-dialog'),
        title: Text(context.l10n.workspaceCouldNotImportTitle),
        content: Text(error.message),
        actions: [
          TextButton(
            key: const Key('import-error-ok-button'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.commonOk),
          ),
        ],
      ),
    );
  } catch (error) {
    showToast(ref, l10n.workspaceCouldNotImport(error));
  }
}
