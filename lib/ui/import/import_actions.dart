import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/import/import_result.dart';
import '../../engine/models/models.dart';
import '../collections/collections_provider.dart';
import '../environments/environments_provider.dart';

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
