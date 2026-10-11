import '../import_json.dart';
import '../import_result.dart';
import 'openapi_refs.dart';

/// Works out an example value for an OpenAPI schema: what the file gives (`example`,
/// `default`, `const`, `enum`) or, failing that, a plain sample built from the shape.
///
/// A schema can be enormous or refer to itself, and a hostile file can share one node a
/// million times over (YAML aliases), so every sample has a small allowance of depth and
/// nodes; when it runs out the rest is left out and a warning says so.
class SchemaSampler {
  SchemaSampler(this._refs, this._warnings);

  /// How many levels of objects and arrays a sample may have.
  static const int maxDepth = 8;

  /// How many values (of any kind) one sample may have.
  static const int maxNodes = 2000;

  /// Where an example given by the file stops being followed (only a guard for the stack).
  static const int _maxExampleDepth = 32;

  final OpenApiRefs _refs;
  final List<ImportWarning> _warnings;
  final Set<String> _cycleWarned = {};

  /// An example for [schema], as plain JSON data (maps with text keys, lists, text,
  /// numbers, booleans, null). [where] locates any warning.
  Object? sample(Object? schema, {String where = ''}) {
    final run = _Run();
    final value = _sample(schema, run, 0, const [], where);
    if (run.cut) {
      _warnings.add(ImportWarning(where: where, message: 'the example was cut short (it is too deep or too large)'));
    }
    return identical(value, _omit) ? null : value;
  }

  /// What the file itself gives for [schema] (`example`, `default`, `const`, or the first
  /// `enum` value), or `found: false` when it says nothing: a parameter that is required
  /// but has none of these becomes a variable to fill in rather than an invented value.
  ({bool found, Object? value}) given(Object? schema, {String where = ''}) {
    final map = _refs.resolve(schema, where: where);
    if (map == null) return (found: false, value: null);
    for (final key in const ['example', 'default', 'const']) {
      if (map.containsKey(key)) return (found: true, value: plainExample(map[key], where: where));
    }
    final choices = asList(map['enum']);
    if (choices.isNotEmpty) return (found: true, value: plainExample(choices.first, where: where));
    return (found: false, value: null);
  }

  /// [value] (an example the file gives) as plain JSON data, within the allowance.
  Object? plainExample(Object? value, {String where = ''}) {
    final run = _Run();
    final plain = _plain(value, run, 0);
    if (run.cut) {
      _warnings.add(ImportWarning(where: where, message: 'the example was cut short (it is too deep or too large)'));
    }
    return plain;
  }

  /// Stands for "leave this out of the object or array that holds it" (a recursive part).
  static final Object _omit = Object();

  Object? _sample(Object? schema, _Run run, int depth, List<String> stack, String where) {
    if (++run.nodes > maxNodes || depth > maxDepth) {
      run.cut = true;
      return null;
    }

    var map = asMap(schema);
    if (map == null) return null;

    var path = stack;
    final ref = map[r'$ref'];
    if (ref is String) {
      if (stack.contains(ref)) {
        if (_cycleWarned.add(ref)) {
          _warnings.add(ImportWarning(
            message: 'schema "$ref" refers to itself; the recursive part was left out of the examples',
          ));
        }
        return _omit;
      }
      path = [...stack, ref];
      final resolved = _refs.resolve(map, where: where);
      if (resolved == null) return null;
      map = resolved;
    }

    for (final key in const ['example', 'default', 'const']) {
      if (map.containsKey(key)) return _plain(map[key], run, 0);
    }
    final choices = asList(map['enum']);
    if (choices.isNotEmpty) return _plain(choices.first, run, 0);

    final allOf = asList(map['allOf']);
    if (allOf.isNotEmpty) return _allOf(map, allOf, run, depth, path, where);
    for (final key in const ['oneOf', 'anyOf']) {
      final alternatives = asList(map[key]);
      if (alternatives.isNotEmpty) return _sample(alternatives.first, run, depth + 1, path, where);
    }

    switch (_typeOf(map)) {
      case 'object':
        return _object(map, run, depth, path, where);
      case 'array':
        final items = map['items'];
        if (items == null) return <Object?>[];
        final item = _sample(items, run, depth + 1, path, where);
        return identical(item, _omit) ? _omit : [item];
      case 'string':
        return _string(asString(map['format']));
      case 'integer':
      case 'number':
        final minimum = map['minimum'];
        return minimum is num ? minimum : 0;
      case 'boolean':
        return true;
      default:
        return null;
    }
  }

  /// The type of [schema]: `type` (the first one that is not `null` when it is a list, as
  /// in 3.1), or guessed from `properties` / `items`; null when there is nothing to go on.
  String? _typeOf(Map<String, dynamic> schema) {
    final type = schema['type'];
    if (type is String) return type;
    if (type is List) {
      final names = type.whereType<String>().toList();
      if (names.isEmpty) return null;
      return names.firstWhere((name) => name != 'null', orElse: () => 'null');
    }
    if (schema.containsKey('properties')) return 'object';
    if (schema.containsKey('items')) return 'array';
    return null;
  }

  Object? _object(Map<String, dynamic> schema, _Run run, int depth, List<String> path, String where) {
    final result = <String, Object?>{};
    final properties = asMap(schema['properties']) ?? const <String, dynamic>{};
    for (final entry in properties.entries) {
      // Out of allowance: the rest of the properties would only be empty keys, and a wide
      // schema shared by thousands of operations would make each body as big as the schema.
      if (run.nodes > maxNodes) break;
      // What a server sends back (readOnly) is not something to put in a request.
      if (_refs.resolve(entry.value, where: where)?['readOnly'] == true) continue;
      final value = _sample(entry.value, run, depth + 1, path, where);
      if (run.nodes > maxNodes && value == null) break;
      if (!identical(value, _omit)) result[entry.key] = value;
    }
    return result;
  }

  Object? _allOf(Map<String, dynamic> schema, List<dynamic> parts, _Run run, int depth, List<String> path, String where) {
    final merged = <String, Object?>{};
    var foundObject = false;
    Object? other;

    void take(Object? value) {
      if (value is Map<String, Object?>) {
        foundObject = true;
        for (final entry in value.entries) {
          merged.putIfAbsent(entry.key, () => entry.value);
        }
      } else if (other == null && !identical(value, _omit)) {
        other = value;
      }
    }

    if (schema.containsKey('properties')) take(_object(schema, run, depth, path, where));
    for (final part in parts) {
      take(_sample(part, run, depth + 1, path, where));
    }
    return foundObject ? merged : other;
  }

  /// A short text that looks like [format], or `string`.
  String _string(String? format) => switch (format) {
        'date-time' => '2024-01-01T00:00:00Z',
        'date' => '2024-01-01',
        'email' => 'user@example.com',
        'uuid' => '00000000-0000-0000-0000-000000000000',
        'uri' => 'https://example.com',
        _ => 'string',
      };

  /// [value] (an example the file gives) as plain JSON data, within the same allowance:
  /// YAML maps with number keys become text keys, and a node shared a million times is
  /// copied only until the allowance runs out.
  Object? _plain(Object? value, _Run run, int depth) {
    if (++run.nodes > maxNodes || depth > _maxExampleDepth) {
      run.cut = true;
      return null;
    }
    if (value is Map) {
      return {for (final entry in value.entries) '${entry.key}': _plain(entry.value, run, depth + 1)};
    }
    if (value is List) return [for (final item in value) _plain(item, run, depth + 1)];
    if (value == null || value is String || value is num || value is bool) return value;
    return '$value';
  }
}

/// What one sample has used up.
class _Run {
  int nodes = 0;
  bool cut = false;
}
