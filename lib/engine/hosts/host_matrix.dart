import '../models/models.dart';

/// True when [value] looks like an http(s) URL (case-insensitive, trimmed).
bool isHostUrl(String value) {
  final v = value.trim().toLowerCase();
  return v.startsWith('http://') || v.startsWith('https://');
}

/// One base (host): an environment variable whose value is a URL, with its
/// value in every environment that defines it.
class HostRow {
  const HostRow({
    required this.name,
    required this.valueByEnvironmentId,
    required this.missingEnvironmentIds,
    required this.note,
    required this.usedBy,
  });

  final String name;

  /// The value per environment id, only for environments that define it
  /// (a blank value counts as not defined).
  final Map<String, String> valueByEnvironmentId;

  /// Ids of the environments that do not define this base, in column order.
  final List<String> missingEnvironmentIds;

  /// The note typed for this base, empty if none.
  final String note;

  /// How many saved requests have `{{name}}` in their URL.
  final int usedBy;

  String? valueIn(String environmentId) => valueByEnvironmentId[environmentId];

  bool get isMissingSomewhere => missingEnvironmentIds.isNotEmpty;
}

/// The hosts-by-environment table: [environments] are the columns (in their
/// own order) and [rows] the bases, sorted by name.
class HostMatrix {
  const HostMatrix({required this.environments, required this.rows});

  final List<Environment> environments;
  final List<HostRow> rows;
}

/// Builds the matrix. A variable is a base when its value is a URL in at least
/// one environment and it is `secret` in none (secrets are never listed).
HostMatrix buildHostMatrix(
  List<Environment> environments,
  List<Endpoint> endpoints,
  Map<String, String> notes,
) {
  final names = <String>{};
  final secretNames = <String>{};
  for (final environment in environments) {
    for (final entry in environment.variables.entries) {
      if (entry.value.secret) secretNames.add(entry.key);
      if (isHostUrl(entry.value.value)) names.add(entry.key);
    }
  }
  names.removeAll(secretNames);

  final rows = [
    for (final name in names)
      _buildRow(name, environments, endpoints, notes[name] ?? ''),
  ]..sort((a, b) => a.name.compareTo(b.name));

  return HostMatrix(environments: environments, rows: rows);
}

HostRow _buildRow(String name, List<Environment> environments, List<Endpoint> endpoints, String note) {
  final values = <String, String>{};
  final missing = <String>[];
  for (final environment in environments) {
    final value = environment.variables[name]?.value ?? '';
    if (value.trim().isEmpty) {
      missing.add(environment.id);
    } else {
      values[environment.id] = value;
    }
  }

  final token = '{{$name}}';
  return HostRow(
    name: name,
    valueByEnvironmentId: values,
    missingEnvironmentIds: missing,
    note: note,
    usedBy: endpoints.where((e) => e.url.contains(token)).length,
  );
}
