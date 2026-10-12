import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/flows/flows_file.dart';
import '../../engine/import/importer.dart';
import '../collections/collections_provider.dart';
import '../import/import_file_dialogs.dart';
import '../shell/app_toast.dart';
import '../workspace_transfer/workspace_file_dialogs.dart';
import 'flow_selection_dialog.dart';
import 'flows_provider.dart';

String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// Export: asks which flows, then saves them with the requests they use to a file the
/// person picks. Cancelling either dialog does nothing.
Future<void> exportFlows(BuildContext context, WidgetRef ref) async {
  try {
    final flows = await ref.read(flowsProvider.future);
    if (flows.isEmpty) {
      showToast(ref, 'There are no flows to export yet');
      return;
    }
    if (!context.mounted) return;
    final ids = await showFlowSelectionDialog(context, title: 'Export flows', confirmLabel: 'Export', flows: flows);
    if (ids == null) return;

    final chosen = [for (final f in flows) if (ids.contains(f.id)) f];
    final collections = await ref.read(collectionsProvider.future);
    final file = buildFlowsFile(chosen, groups: collections.groups, endpoints: collections.endpoints);
    final saved = await ref.read(workspaceFileDialogsProvider).saveText(flowsFileName(chosen), file.encode());
    if (!saved) return;
    showToast(ref, 'Exported ${_count(chosen.length, 'flow', 'flows')} — credentials are not included');
  } catch (error) {
    showToast(ref, 'Could not export the flows: $error');
  }
}

/// Import: asks for a flows file, then which of its flows to bring in, and adds them to
/// the active project as new flows. The requests they use are matched with the ones the
/// project has (same method and URL) and only the missing ones are added.
Future<void> importFlows(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await ref.read(importFileDialogsProvider).pickFile(const ['json']);
    if (picked == null) return;
    checkImportFileSize(picked.sizeBytes);
    final file = FlowsFile.parse(await picked.read());
    if (file.flows.isEmpty) {
      if (context.mounted) await _showError(context, 'That file has no flows in it.');
      return;
    }

    if (!context.mounted) return;
    final ids = await showFlowSelectionDialog(context, title: 'Import flows', confirmLabel: 'Import', flows: file.flows);
    if (ids == null) return;

    final collections = ref.read(collectionsProvider.notifier);
    final before = await ref.read(collectionsProvider.future);
    final plan = planFlowsImport(
      file,
      selected: ids,
      existingGroups: before.groups,
      existingEndpoints: before.endpoints,
      existingFlows: await ref.read(flowsProvider.future),
    );

    await collections.append(groups: plan.newGroups, endpoints: plan.newEndpoints);
    try {
      await ref.read(flowsProvider.notifier).addAll(plan.flows);
    } catch (_) {
      await collections.restore(before);
      rethrow;
    }

    final parts = [
      if (plan.newEndpoints.isNotEmpty) '${_count(plan.newEndpoints.length, 'request', 'requests')} added',
      if (plan.reusedEndpoints > 0) '${_count(plan.reusedEndpoints, 'request', 'requests')} already there',
      if (plan.missingSteps > 0) '${_count(plan.missingSteps, 'step', 'steps')} without a request',
      if (plan.filesToChoose > 0) '${_count(plan.filesToChoose, 'file', 'files')} to choose',
    ];
    showToast(ref, 'Imported ${_count(plan.flows.length, 'flow', 'flows')}${parts.isEmpty ? '' : ' — ${parts.join(', ')}'}');
  } on FlowsFileException catch (error) {
    if (context.mounted) await _showError(context, error.message);
  } on ImportException catch (error) {
    if (context.mounted) await _showError(context, error.message);
  } catch (error) {
    if (context.mounted) await _showError(context, 'Could not import the flows: $error');
  }
}

Future<void> _showError(BuildContext context, String message) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('flows-import-error-dialog'),
        title: const Text('Could not import the flows'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
