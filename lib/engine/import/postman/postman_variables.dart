import '../../variables/dynamic_values.dart';
import '../import_result.dart';

/// Rewrites the `{{variables}}` of a Postman file into ones this app resolves, and
/// remembers what it renamed so that can be reported once for the whole file.
///
/// The engine only resolves `{{name}}` with letters, digits and `_`, so `{{base-url}}`
/// would never be filled in: it becomes `{{base_url}}`, here and in the environment
/// keys alike. Postman's dynamic variables are mapped onto [DynamicValues].
class VariableTranslator {
  /// Names that had to change, original → new.
  final Map<String, String> renamed = {};

  static final RegExp _token = RegExp(r'\{\{([^{}]+)\}\}');
  static final RegExp _plainName = RegExp(r'^\w+$');
  static final RegExp _notWord = RegExp(r'\W');

  /// Postman dynamic variable → this app's.
  static const Map<String, String> _dynamicNames = {
    'guid': 'uuid',
    'randomUUID': 'uuid',
    'randomAlphaNumeric': 'randomString',
  };

  /// [text] with every variable rewritten. A dynamic variable this app cannot
  /// generate is left as written and its name added to [unknownDynamic], for the caller
  /// to report where it was found.
  String translate(String text, {List<String>? unknownDynamic}) {
    return text.replaceAllMapped(_token, (match) {
      final inner = match[1]!.trim();
      if (inner.isEmpty) return match[0]!;

      if (inner.startsWith(r'$')) {
        final postmanName = inner.substring(1).trim();
        final name = _dynamicNames[postmanName] ?? (DynamicValues.isKnown(postmanName) ? postmanName : null);
        if (name == null) {
          if (unknownDynamic != null && !unknownDynamic.contains(postmanName)) unknownDynamic.add(postmanName);
          return '{{\$$postmanName}}';
        }
        return '{{\$$name}}';
      }
      return '{{${sanitizeName(inner)}}}';
    });
  }

  /// [name] as a variable name the engine can resolve (the same rewrite every time).
  String sanitizeName(String name) {
    if (_plainName.hasMatch(name)) return name;
    final fixed = name.replaceAll(_notWord, '_');
    renamed[name] = fixed;
    return fixed;
  }

  /// One warning for the whole file listing every rename, or null if there were none.
  ImportWarning? renamedWarning() {
    if (renamed.isEmpty) return null;
    final changes = renamed.entries.map((e) => '${e.key} → ${e.value}').join(', ');
    return ImportWarning(message: 'variable names changed (only letters, digits and _ are supported): $changes');
  }
}

/// The warning for [names] (dynamic variables this app cannot generate) found at [where].
List<ImportWarning> unknownDynamicWarnings(String where, Iterable<String> names) => [
      for (final name in names)
        ImportWarning(where: where, message: 'unknown dynamic variable {{\$$name}} left as written'),
    ];
