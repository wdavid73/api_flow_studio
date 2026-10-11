import 'selection.dart';

/// Hides sensitive values in anything the runner writes.
///
/// It is a plain-text match, not a vault: a secret the server sends back in some
/// other format can still show. Values shorter than [minLength] are never
/// masked (masking `1` would wreck every number in the output).
class Redactor {
  Redactor([Iterable<String> values = const []]) {
    values.forEach(_add);
  }

  /// The values to mask: secret environment variables as they stand after the
  /// command line was applied, and the values given from outside the file -- except
  /// those given for a variable the environment declares as plain (`base_url`), which
  /// the file itself says is not a secret and whose masking would blank every URL in
  /// the output. A plain variable with a credential-like name (`service_token`) is
  /// still masked, and so is anything the environment does not declare.
  factory Redactor.forSelection(RunSelection selection) {
    final declared = selection.environment?.variables ?? const {};
    // A declared secret is masked by the first loop below, whatever its override.
    bool declaredPlain(String name) => declared.containsKey(name) && !_sensitiveName.hasMatch(name);

    return Redactor([
      for (final name in selection.secretNames) selection.variables[name] ?? '',
      for (final entry in selection.overrides.entries)
        if (!declaredPlain(entry.key)) entry.value,
    ]);
  }

  static const int minLength = 4;
  static const String mask = '***';

  /// Names that suggest a value extracted from a response is a credential.
  static final RegExp _sensitiveName = RegExp('token|secret|password|key|auth', caseSensitive: false);

  final Set<String> _values = {};
  List<String> _longestFirst = const [];

  /// Starts masking the values a step extracted into variables whose name looks
  /// sensitive. Call it before writing that step's output.
  void learn(Map<String, String> extracted) {
    for (final entry in extracted.entries) {
      if (_sensitiveName.hasMatch(entry.key)) _add(entry.value);
    }
  }

  String redact(String text) {
    var result = text;
    for (final value in _longestFirst) {
      result = result.replaceAll(value, mask);
    }
    return result;
  }

  void _add(String value) {
    if (value.length < minLength) return;
    // The form it takes inside a URL, where a secret with special characters is escaped.
    for (final form in {value, Uri.encodeQueryComponent(value), Uri.encodeComponent(value)}) {
      _values.add(form);
    }
    _longestFirst = _values.toList()..sort((a, b) => b.length.compareTo(a.length));
  }
}
