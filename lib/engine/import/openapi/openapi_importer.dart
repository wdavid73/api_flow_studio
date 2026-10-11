import 'package:yaml/yaml.dart';

import '../../models/models.dart';
import '../import_json.dart';
import '../import_result.dart';
import '../import_source.dart';
import '../importer.dart';

/// An OpenAPI 3.0 or 3.1 specification, in JSON or YAML. Every operation becomes a
/// request, grouped by tag inside a folder named after the API.
///
/// Nothing the document mentions is fetched or read: only references inside the file
/// are followed. A Swagger 2.0 file is recognised only to explain that it is not supported.
class OpenApiImporter implements Importer {
  const OpenApiImporter();

  @override
  String get formatName => 'OpenAPI spec';

  @override
  List<String> get extensions => const ['json', 'yaml', 'yml'];

  /// A line in the first column: `openapi: 3.…` (quoted or not) or `swagger: …`. Looking at
  /// the text keeps this cheap: every importer gets to ask, and a big YAML file should be
  /// parsed once, by the importer that owns it.
  static final RegExp _yamlOpenApi = RegExp('^openapi\\s*:\\s*["\']?3\\.', multiLine: true);
  static final RegExp _yamlSwagger = RegExp(r'^swagger\s*:', multiLine: true);

  @override
  bool matches(ImportSource source) {
    final json = source.json;
    if (json is Map) {
      final version = json['openapi'];
      return (version is String && version.startsWith('3.')) || json['swagger'] != null;
    }
    if (json != null) return false;
    return _yamlOpenApi.hasMatch(source.text) || _yamlSwagger.hasMatch(source.text);
  }

  @override
  ImportResult parse(ImportSource source) {
    final document = loadOpenApiDocument(source);
    final title = (asString(asMap(document['info'])?['title']) ?? '').trim();
    final version = '${document['openapi']}'.split('.').take(2).join('.');

    return ImportResult(
      source: 'OpenAPI $version spec',
      groups: [Group(id: 'openapi-group-1', name: title.isEmpty ? 'OpenAPI spec' : title)],
    );
  }
}

/// The document of [source] as a map: its JSON, or its YAML read directly (not copied, so
/// aliases stay shared instead of being expanded). Throws [ImportException] when it is not
/// valid, is not a mapping, or is Swagger 2.0.
Map<String, dynamic> loadOpenApiDocument(ImportSource source) {
  Object? document = source.json;
  if (document == null) {
    try {
      document = loadYaml(source.text);
    } on YamlException catch (error) {
      final line = error.span?.start.line;
      throw ImportException(line == null ? 'That file is not valid YAML.' : 'That file is not valid YAML (line ${line + 1}).');
    }
  }

  final map = asMap(document);
  if (map == null) throw const ImportException('That file is not an OpenAPI document.');
  if (map['swagger'] != null) {
    throw const ImportException('That is a Swagger 2.0 file, which is not supported. Convert it to OpenAPI 3 first.');
  }
  return map;
}
