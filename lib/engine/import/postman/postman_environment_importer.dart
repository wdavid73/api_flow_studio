import '../../models/models.dart';
import '../import_result.dart';
import '../import_source.dart';
import '../importer.dart';
import 'postman_json.dart';
import 'postman_variables.dart';

/// A Postman environment file, or its globals: `{name, values: [{key, value, type,
/// enabled}], _postman_variable_scope}`. It becomes one environment, never activated.
class PostmanEnvironmentImporter implements Importer {
  const PostmanEnvironmentImporter();

  @override
  String get formatName => 'Postman environment';

  @override
  List<String> get extensions => const ['json'];

  @override
  bool matches(ImportSource source) {
    final json = asMap(source.json);
    if (json == null || json.containsKey('info') || json.containsKey('item')) return false;
    final values = json['values'];
    if (values is! List) return false;
    return json['_postman_variable_scope'] is String || values.every((v) => v is Map && v.containsKey('key'));
  }

  @override
  ImportResult parse(ImportSource source) {
    final json = asMap(source.json)!;
    final isGlobals = json['_postman_variable_scope'] == 'globals';
    final translator = VariableTranslator();
    final warnings = <ImportWarning>[];

    final variables = <String, EnvironmentVariable>{};
    final disabled = <String>[];
    var withoutName = 0;

    for (final entry in asList(json['values'])) {
      final map = asMap(entry);
      final key = map == null ? null : asString(map['key']);
      if (map == null || key == null || key.isEmpty) {
        withoutName++;
        continue;
      }
      if (map['enabled'] == false) {
        disabled.add(key);
        continue;
      }

      final name = translator.sanitizeName(key);
      if (variables.containsKey(name)) {
        warnings.add(ImportWarning(where: key, message: 'variable "$key" is repeated; the first value was kept'));
        continue;
      }
      final unknown = <String>[];
      final raw = map['value'];
      final value = translator.translate(raw == null ? '' : '$raw', unknownDynamic: unknown);
      warnings.addAll(unknownDynamicWarnings(key, unknown));
      variables[name] = EnvironmentVariable(value: value, secret: map['type'] == 'secret');
    }

    if (withoutName > 0) {
      warnings.add(ImportWarning(
        message: withoutName == 1
            ? '1 entry without a variable name was skipped'
            : '$withoutName entries without a variable name were skipped',
      ));
    }
    if (disabled.isNotEmpty) warnings.add(ImportWarning(message: 'disabled variables were left out: ${disabled.join(', ')}'));
    final renamed = translator.renamedWarning();
    if (renamed != null) warnings.add(renamed);

    final name = (asString(json['name']) ?? '').trim();
    return ImportResult(
      source: isGlobals ? 'Postman globals' : formatName,
      environments: [
        Environment(
          id: 'postman-environment',
          name: name.isEmpty ? (isGlobals ? 'Postman globals' : formatName) : name,
          variables: variables,
        ),
      ],
      warnings: warnings,
    );
  }
}
