import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/workspace/export_workspace.dart';
import '../../engine/workspace/workspace_file.dart';
import '../projects/projects_provider.dart';
import '../shell/app_toast.dart';
import 'workspace_file_dialogs.dart';

/// Saves the active project to a workspace file the person picks.
Future<void> exportActiveProject(WidgetRef ref) async {
  final state = ref.read(projectsProvider);
  final dialogs = ref.read(workspaceFileDialogsProvider);

  try {
    final file = await exportWorkspace(state.store, state.active);
    final saved = await dialogs.saveText(workspaceFileName(state.active.name), file.encode());
    if (!saved) return; // cancelled: nothing to say
    showToast(ref, 'Workspace "${state.active.name}" exported — secrets are not included');
  } catch (error) {
    showToast(ref, 'Could not save the workspace: $error');
  }
}

/// Imports a workspace file the person picks as a new project and switches to
/// it. A file that cannot be used is explained in a dialog.
Future<void> importWorkspaceFromFile(BuildContext context, WidgetRef ref) async {
  final dialogs = ref.read(workspaceFileDialogsProvider);

  final String? text;
  try {
    text = await dialogs.openText();
  } catch (error) {
    showToast(ref, 'Could not read the file: $error');
    return;
  }
  if (text == null) return;

  try {
    final imported = await ref.read(projectsProvider.notifier).importWorkspace(text);
    final name = imported.project.name;
    final pending = imported.secretsToFill;
    showToast(
      ref,
      pending == 0
          ? 'Imported "$name"'
          : 'Imported "$name" — $pending secret ${pending == 1 ? 'value' : 'values'} to fill in',
    );
  } on WorkspaceFileException catch (error) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('import-error-dialog'),
        title: const Text('Could not import the workspace'),
        content: Text(error.message),
        actions: [
          TextButton(
            key: const Key('import-error-ok-button'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  } catch (error) {
    showToast(ref, 'Could not import the workspace: $error');
  }
}
