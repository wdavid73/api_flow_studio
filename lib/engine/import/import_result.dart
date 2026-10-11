import '../models/models.dart';

/// Something a file contained that could not be brought in, or only in part.
class ImportWarning {
  const ImportWarning({this.where = '', required this.message});

  /// Where in the file it was (`Auth / Login`, `paths./pets.get`); empty when it
  /// is about the file as a whole.
  final String where;
  final String message;
}

/// What a file contained, translated into the app's own model. Plain data: no ids
/// that matter (they are regenerated on import) and no effects. An importer must
/// leave a warning for everything it drops or simplifies.
class ImportResult {
  const ImportResult({
    required this.source,
    this.groups = const [],
    this.endpoints = const [],
    this.environments = const [],
    this.warnings = const [],
  });

  /// What it was, for messages: `Postman collection`, `OpenAPI 3.0 spec`.
  final String source;

  /// The whole folder tree; roots have no parent. Endpoints point at these ids.
  final List<Group> groups;
  final List<Endpoint> endpoints;
  final List<Environment> environments;
  final List<ImportWarning> warnings;
}

/// What an import did, for the person to read.
class ImportSummary {
  const ImportSummary({
    required this.source,
    required this.folders,
    required this.requests,
    required this.environments,
    required this.valuesToFill,
    required this.warnings,
  });

  final String source;
  final int folders;
  final int requests;
  final int environments;

  /// Secret variables of the imported environments that came empty.
  final int valuesToFill;
  final List<ImportWarning> warnings;

  /// One line: `Imported Postman collection: 12 requests in 4 folders, 1 environment
  /// — 2 values to fill in`. The warnings are listed apart, not here.
  String describe() {
    String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

    final parts = [
      if (requests > 0 || folders > 0) '${count(requests, 'request', 'requests')} in ${count(folders, 'folder', 'folders')}',
      if (environments > 0) count(environments, 'environment', 'environments'),
    ];
    final fill = valuesToFill > 0 ? ' — ${count(valuesToFill, 'value', 'values')} to fill in' : '';
    return 'Imported $source: ${parts.isEmpty ? 'nothing' : parts.join(', ')}$fill';
  }
}
