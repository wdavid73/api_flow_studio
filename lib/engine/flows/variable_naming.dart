import 'response_fields.dart';

/// Field names too vague to stand alone as a variable: `user.id` reads better
/// as `user_id` than as `id`.
const Set<String> _genericNames = {'id', 'name', 'token', 'code', 'value', 'key', 'uuid'};

/// Segments that only wrap the payload and add nothing to a name.
const Set<String> _containerNames = {'data', 'result', 'response', 'body'};

final RegExp _validName = RegExp(r'^\w+$');
final RegExp _camelBoundary = RegExp(r'([a-z0-9])([A-Z])');
final RegExp _notWord = RegExp(r'\W+');

/// Whether [name] can be used as `{{name}}` (the interpolator only resolves
/// letters, digits and `_`).
bool isValidVariableName(String name) => _validName.hasMatch(name);

/// A variable name for the value at [path]: its last segment in snake_case,
/// with the segment before it in front when the last one is generic
/// (`response.body.user.id` → `user_id`). List indexes are skipped.
String suggestVariableName(String path) {
  final segments = _nameSegments(path);
  if (segments.isEmpty) return 'value';
  final last = segments.last;
  final parts = [last];
  if (_genericNames.contains(last.toLowerCase()) && segments.length > 1) {
    final previous = segments[segments.length - 2];
    if (!_containerNames.contains(previous.toLowerCase())) parts.insert(0, previous);
  }
  return parts.map(_snakeCase).join('_');
}

/// The nearest step before [stepIndex] whose response has a field that matches
/// [name], and that field's path; null when none does. Names match when they
/// are equal ignoring case, `_` and `-` (`userId` = `user_id`), against the
/// field's last segment or its last two joined (`user.id` → `userid`).
({int stepIndex, String path})? suggestConnection({
  required String name,
  required int stepIndex,
  required Map<int, List<ResponseField>> fieldsByStep,
}) {
  final wanted = _normalize(name);
  for (var j = stepIndex - 1; j >= 0; j--) {
    for (final field in fieldsByStep[j] ?? const <ResponseField>[]) {
      final segments = _nameSegments(field.path);
      if (segments.isEmpty) continue;
      final last = _normalize(segments.last);
      final lastTwo = segments.length > 1 ? _normalize(segments[segments.length - 2]) + last : null;
      if (wanted == last || wanted == lastTwo) return (stepIndex: j, path: field.path);
    }
  }
  return null;
}

/// The segments of [path] after `response`, without list indexes.
List<String> _nameSegments(String path) =>
    path.split('.').skip(1).where((s) => s.isNotEmpty && int.tryParse(s) == null).toList();

String _snakeCase(String segment) => segment
    .replaceAllMapped(_camelBoundary, (m) => '${m[1]}_${m[2]}')
    .replaceAll(_notWord, '_')
    .toLowerCase();

String _normalize(String name) => name.toLowerCase().replaceAll(RegExp('[_-]'), '');
