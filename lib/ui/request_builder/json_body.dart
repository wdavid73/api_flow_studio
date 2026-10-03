import 'dart:convert';

final RegExp _variable = RegExp(r'\{\{\w+\}\}');

/// Whether [raw] is acceptable as a JSON request body. An empty body counts
/// as valid (nothing typed yet). `{{variables}}` are tolerated both inside
/// strings and as bare values (`{"id": {{id}}}`), since they are replaced
/// with real values before sending.
bool isValidJsonBody(String raw) {
  if (raw.trim().isEmpty) return true;
  try {
    jsonDecode(raw.replaceAll(_variable, '0'));
    return true;
  } catch (_) {
    return false;
  }
}

/// [raw] pretty-printed with two-space indentation, or null when it can't be
/// formatted safely: empty, invalid, or containing a bare `{{variable}}`
/// that re-encoding would turn into a number.
String? formatJsonBody(String raw) {
  if (raw.trim().isEmpty) return null;
  try {
    return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
  } catch (_) {
    return null;
  }
}
