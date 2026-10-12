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
import '../../l10n/l10n.dart';

String _problemText(AppLocalizations l10n, FlowsFileProblem problem) => switch (problem) {
      FlowsFileProblem.tooLarge => l10n.flowsFileTooLarge,
      FlowsFileProblem.notJson => l10n.flowsFileNotJson,
      FlowsFileProblem.notAFlowsFile => l10n.flowsFileNotFlows,
      FlowsFileProblem.newerVersion => l10n.flowsFileNewer,
      FlowsFileProblem.invalid => l10n.flowsFileInvalid,
    };

/// Export: asks which flows, then saves them with the requests they use to a file the
/// person picks. Cancelling either dialog does nothing.
Future<void> exportFlows(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  try {
    final flows = await ref.read(flowsProvider.future);
    if (flows.isEmpty) {
      showToast(ref, l10n.flowsNothingToExport);
      return;
    }
    if (!context.mounted) return;
    final ids = await showFlowSelectionDialog(context, title: l10n.flowsExportTitle, confirmLabel: l10n.commonExport, flows: flows);
    if (ids == null) return;

    final chosen = [for (final f in flows) if (ids.contains(f.id)) f];
    final collections = await ref.read(collectionsProvider.future);
    final file = buildFlowsFile(chosen, groups: collections.groups, endpoints: collections.endpoints);
    final saved = await ref.read(workspaceFileDialogsProvider).saveText(flowsFileName(chosen), file.encode());
    if (!saved) return;
    showToast(ref, l10n.flowsExported(chosen.length));
  } catch (error) {
    showToast(ref, l10n.flowsExportFailed(error));
  }
}

/// Import: asks for a flows file, then which of its flows to bring in, and adds them to
/// the active project as new flows. The requests they use are matched with the ones the
/// project has (same method and URL) and only the missing ones are added.
Future<void> importFlows(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  try {
    final picked = await ref.read(importFileDialogsProvider).pickFile(const ['json']);
    if (picked == null) return;
    checkImportFileSize(picked.sizeBytes);
    final file = FlowsFile.parse(await picked.read());
    if (file.flows.isEmpty) {
      if (context.mounted) await _showError(context, l10n.flowsFileEmpty);
      return;
    }

    if (!context.mounted) return;
    final ids = await showFlowSelectionDialog(context, title: l10n.flowsImportTitle, confirmLabel: l10n.commonImport, flows: file.flows);
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
      if (plan.newEndpoints.isNotEmpty) l10n.flowsPartRequestsAdded(plan.newEndpoints.length),
      if (plan.reusedEndpoints > 0) l10n.flowsPartRequestsReused(plan.reusedEndpoints),
      if (plan.missingSteps > 0) l10n.flowsPartStepsMissing(plan.missingSteps),
      if (plan.filesToChoose > 0) l10n.flowsPartFilesToChoose(plan.filesToChoose),
    ];
    showToast(ref, l10n.flowsImported(l10n.flowsImportedFlowCount(plan.flows.length), parts.isEmpty ? '' : l10n.flowsImportedDetails(parts.join(', '))));
  } on FlowsFileException catch (error) {
    if (context.mounted) await _showError(context, _problemText(l10n, error.problem));
  } on ImportException catch (error) {
    if (context.mounted) await _showError(context, error.message);
  } catch (error) {
    if (context.mounted) await _showError(context, l10n.flowsImportFailed(error));
  }
}

Future<void> _showError(BuildContext context, String message) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('flows-import-error-dialog'),
        title: Text(context.l10n.flowsImportErrorTitle),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.commonOk)),
        ],
      ),
    );
