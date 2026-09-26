import 'dart:convert';

/// Walks a dot-notation path (e.g. `response.body.data.otp`) through a
/// step's response shape (`{ status, headers, body }`), returning the raw
/// value at that path or `null` if any segment is missing, the wrong
/// shape, or an out-of-range array index. A numeric segment indexes into
/// a `List`; anything else indexes into a `Map`. Not a real JSON path
/// parser -- deliberately simple, matching what `FlowStep.extract`/
/// `assertField` values actually look like.
///
/// [dotPath] must start with `response` (either exactly, or with a `.`
/// after it) -- anything else is a programmer error, not a runtime
/// "missing data" case, so it throws [ArgumentError] rather than
/// returning null.
dynamic extractValue(Map<String, dynamic> response, String dotPath) {
  if (dotPath != 'response' && !dotPath.startsWith('response.')) {
    throw ArgumentError.value(dotPath, 'dotPath', 'must start with "response"');
  }

  final segments = dotPath.split('.').skip(1);
  dynamic current = response;

  for (final segment in segments) {
    if (current is Map) {
      current = current[segment];
    } else if (current is List) {
      final index = int.tryParse(segment);
      if (index == null || index < 0 || index >= current.length) return null;
      current = current[index];
    } else {
      return null;
    }
    if (current == null) return null;
  }

  return current;
}

/// [extractValue], coerced to a String for use as a flow variable's value:
/// strings pass through, numbers/booleans use `toString()`, objects/lists
/// are JSON-encoded, and a missing/null value stays `null` (the caller
/// decides whether that means "don't set this variable" or "assertion
/// failed").
String? extractValueAsString(Map<String, dynamic> response, String dotPath) {
  final value = extractValue(response, dotPath);
  if (value == null) return null;
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  try {
    return jsonEncode(value);
  } catch (_) {
    return value.toString();
  }
}
