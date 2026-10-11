import '../import_json.dart';
import '../import_result.dart';

/// Follows the `$ref`s of an OpenAPI document, **inside the document only**.
///
/// A reference to another file or to a URL is never followed or read: it is reported and
/// treated as missing. Chains are cut at [maxHops] and loops are detected, so a hostile
/// file cannot keep it busy. Each problem is warned about once per reference.
class OpenApiRefs {
  OpenApiRefs(this.document, this.warnings);

  /// The most `$ref`s followed one after another.
  static const int maxHops = 20;

  final Map<String, dynamic> document;
  final List<ImportWarning> warnings;
  final Set<String> _warned = {};

  /// The object [value] stands for: itself when it has no `$ref`, otherwise what the
  /// reference (and the references it points at) ends up at. Null when [value] is not an
  /// object or the reference cannot be resolved. [where] locates the warning.
  Map<String, dynamic>? resolve(Object? value, {String where = ''}) {
    Object? current = value;
    final seen = <String>{};
    String? first;

    for (var hops = 0;; hops++) {
      final map = asMap(current);
      if (map == null) return null;
      final ref = map[r'$ref'];
      if (ref is! String) return map;

      first ??= ref;
      if (!seen.add(ref)) {
        _warn(first, 'is circular', where);
        return null;
      }
      if (hops >= maxHops) {
        _warn(first, 'is nested too deeply', where);
        return null;
      }

      final target = _lookup(ref, where);
      if (target == null) return null;
      current = target;
    }
  }

  /// What a single local reference points at, or null (with a warning) if it cannot.
  Object? _lookup(String ref, String where) {
    if (!ref.startsWith('#')) {
      if (_warned.add('external|$ref')) {
        warnings.add(ImportWarning(where: where, message: 'external reference "$ref" was not followed'));
      }
      return null;
    }

    final pointer = ref.substring(1);
    if (pointer.isEmpty) return document;

    Object? node = document;
    if (pointer.startsWith('/')) {
      for (final raw in pointer.substring(1).split('/')) {
        final segment = _decode(raw);
        if (node is Map) {
          node = _child(node, segment);
        } else if (node is List) {
          final index = int.tryParse(segment);
          node = index != null && index >= 0 && index < node.length ? node[index] : null;
        } else {
          node = null;
        }
        if (node == null) break;
      }
    } else {
      node = null;
    }

    if (node is Map || node is List) return node;
    _warn(ref, 'was not found', where);
    return null;
  }

  /// A key of [map], also when the file wrote it as a number (`200:` in YAML).
  Object? _child(Map<dynamic, dynamic> map, String segment) {
    if (map.containsKey(segment)) return map[segment];
    for (final entry in map.entries) {
      if ('${entry.key}' == segment) return entry.value;
    }
    return null;
  }

  /// `~1` is a slash and `~0` a tilde (JSON Pointer), then the `%`-escapes of a URI fragment.
  String _decode(String segment) {
    final pointer = segment.replaceAll('~1', '/').replaceAll('~0', '~');
    try {
      return Uri.decodeComponent(pointer);
    } on ArgumentError {
      return pointer;
    }
  }

  void _warn(String ref, String what, String where) {
    if (_warned.add('$what|$ref')) warnings.add(ImportWarning(where: where, message: 'reference "$ref" $what'));
  }
}
