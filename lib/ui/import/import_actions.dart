import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/import/import_registry.dart';
import '../../engine/import/import_result.dart';
import '../../engine/import/importer.dart';
import '../../engine/models/models.dart';
import '../collections/collections_provider.dart';
import '../environments/environments_provider.dart';
import '../shell/app_toast.dart';
import 'import_file_dialogs.dart';
import 'import_summary_dialog.dart';

/// Puts [result] into the active project, all or nothing, and says what came in.
///
/// Everything is added as **new** things with new ids: folders at the end of the
/// tree (a top-level name already taken gets a number), environments with their own
/// names and none of them active. Nothing that was there is touched. Folders and
/// requests are saved first; if saving the environments then fails, the collections
/// go back to how they were and the error is raised.
///
/// [read] is `ref.read` of a widget or `container.read` of a test.
Future<ImportSummary> applyImport(T Function<T>(ProviderListenable<T> provider) read, ImportResult result) async {
  final collections = read(collectionsProvider.notifier);
  final environments = read(environmentsProvider.notifier);

  final before = await read(collectionsProvider.future);
  await collections.importCollections(groups: result.groups, endpoints: result.endpoints);
  final after = await read(collectionsProvider.future);

  var added = const <Environment>[];
  if (result.environments.isNotEmpty) {
    try {
      added = await environments.addImported(result.environments);
    } catch (_) {
      await collections.restore(before);
      rethrow;
    }
  }

  return ImportSummary(
    source: result.source,
    folders: after.groups.length - before.groups.length,
    requests: after.endpoints.length - before.endpoints.length,
    environments: added.length,
    valuesToFill: [
      for (final environment in added)
        for (final variable in environment.variables.values)
          if (variable.secret && variable.value.isEmpty) variable,
    ].length,
    warnings: result.warnings,
  );
}

/// The Import button: asks for a file, works out what it is, adds it to the active
/// project and reports. A file that cannot be imported is explained in a dialog and
/// nothing changes; cancelling the file dialog does nothing.
Future<void> importFile(BuildContext context, WidgetRef ref) async {
  final picked = await ref.read(importFileDialogsProvider).pickFile(supportedExtensions(importers));
  if (picked == null) return;

  final ImportSummary summary;
  try {
    // The size is checked before the text is read: a huge file is never loaded.
    checkImportFileSize(picked.sizeBytes);
    final String text;
    try {
      text = await picked.read();
    } catch (_) {
      throw const ImportException('Could not read that file.');
    }
    summary = await applyImport(ref.read, runImport(text, importers, fileName: picked.name));
  } on ImportException catch (error) {
    if (context.mounted) await showImportErrorDialog(context, error.message);
    return;
  } catch (error) {
    if (context.mounted) await showImportErrorDialog(context, 'Could not import that file: $error');
    return;
  }

  if (!context.mounted) return;
  if (summary.warnings.isEmpty) {
    showToast(ref, summary.describe());
  } else {
    await showImportSummaryDialog(context, summary);
  }
}
