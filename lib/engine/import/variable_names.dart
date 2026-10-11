import 'import_result.dart';

/// Makes the names of variables something the engine can resolve, and remembers what it
/// had to change so that can be reported once for the whole file.
///
/// The engine only resolves `{{name}}` with letters, digits and `_`, so `{{base-url}}`
/// would never be filled in: it becomes `{{base_url}}`, wherever the name appears.
class VariableNames {
  /// Names that had to change, original → new.
  final Map<String, String> renamed = {};

  static final RegExp _plainName = RegExp(r'^\w+$');
  static final RegExp _notWord = RegExp(r'\W');

  /// [name] as a variable name the engine can resolve (the same rewrite every time).
  String sanitize(String name) {
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
