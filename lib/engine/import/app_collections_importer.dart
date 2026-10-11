import '../models/models.dart';
import 'import_result.dart';
import 'import_source.dart';
import 'importer.dart';

/// The collections file the app itself exports (`{groups, endpoints}`, the shape
/// of `collections.json`): the Export button of the sidebar, and
/// `sample-endpoints.json`.
class AppCollectionsImporter implements Importer {
  const AppCollectionsImporter();

  @override
  String get formatName => 'API Flow Studio collections';

  @override
  List<String> get extensions => const ['json'];

  /// Keys that belong to other formats: a file with them is not ours even if it
  /// happens to have a `groups` or `endpoints` list too.
  static const _foreignKeys = ['info', 'item', 'openapi', 'swagger', 'values'];

  @override
  bool matches(ImportSource source) {
    final json = source.json;
    if (json is! Map) return false;
    if (_foreignKeys.any(json.containsKey)) return false;
    return json['groups'] is List || json['endpoints'] is List;
  }

  @override
  ImportResult parse(ImportSource source) {
    final json = source.json as Map;
    final groups = [for (final g in (json['groups'] as List?) ?? const []) Group.fromJson(g as Map<String, dynamic>)];
    final groupIds = {for (final g in groups) g.id};
    final warnings = <ImportWarning>[];

    // mergeImportedCollections attaches a folder whose parent is unknown at the top
    // level; say so here, where the name is still known.
    final tidyGroups = [
      for (final g in groups)
        if (g.parentGroupId != null && !groupIds.contains(g.parentGroupId))
          () {
            warnings.add(ImportWarning(where: g.name, message: 'its parent folder is not in the file; imported at the top level'));
            return g.copyWith(parentGroupId: null);
          }()
        else
          g,
    ];

    final endpoints = <Endpoint>[];
    for (final e in (json['endpoints'] as List?) ?? const []) {
      final endpoint = Endpoint.fromJson(e as Map<String, dynamic>);
      if (groupIds.contains(endpoint.groupId)) {
        endpoints.add(endpoint);
      } else {
        warnings.add(ImportWarning(where: endpoint.name, message: 'its folder is not in the file; skipped'));
      }
    }

    return ImportResult(source: formatName, groups: tidyGroups, endpoints: endpoints, warnings: warnings);
  }
}
