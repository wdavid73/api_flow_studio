import 'package:yaml/yaml.dart';

import '../../models/models.dart';
import '../import_json.dart';
import '../import_result.dart';
import '../import_source.dart';
import '../importer.dart';
import 'openapi_context.dart';
import 'openapi_operation.dart';

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
    final warnings = <ImportWarning>[];
    final context = OpenApiContext(document, warnings);

    final title = (asString(asMap(document['info'])?['title']) ?? '').trim();
    final apiName = title.isEmpty ? 'OpenAPI spec' : title;
    final version = '${document['openapi']}'.split('.').take(2).join('.');

    final root = Group(id: 'openapi-group-1', name: apiName);
    final groups = <Group>[root];
    final endpoints = <Endpoint>[];

    _defineBaseUrl(context);
    final operations = _operations(context);

    // Folders: the tags the file declares (those that have operations), then the others.
    final used = <String>[];
    for (final operation in operations) {
      if (operation.tag != null && !used.contains(operation.tag)) used.add(operation.tag!);
    }
    final declared = [
      for (final tag in asList(document['tags']))
        if (asString(asMap(tag)?['name']) case final name? when used.contains(name)) name,
    ];
    final ordered = [...declared, ...used.where((tag) => !declared.contains(tag))];
    final folderOf = <String, String>{};
    for (final (i, tag) in ordered.indexed) {
      final group = Group(id: 'openapi-group-${groups.length + 1}', name: tag, parentGroupId: root.id, order: i);
      groups.add(group);
      folderOf[tag] = group.id;
    }

    for (final operation in operations) {
      endpoints.add(operationToEndpoint(
        path: operation.path,
        method: operation.method,
        operation: operation.operation,
        pathParameters: operation.pathParameters,
        context: context,
        id: 'openapi-request-${endpoints.length + 1}',
        groupId: operation.tag == null ? root.id : folderOf[operation.tag]!,
      ));
    }

    // They are described in the file but are not requests you send: nothing to import.
    final hasCallbacks = operations.any((operation) => (asMap(operation.operation['callbacks']) ?? const {}).isNotEmpty);
    if ((asMap(document['webhooks']) ?? const {}).isNotEmpty || hasCallbacks) {
      warnings.add(const ImportWarning(message: 'webhooks and callbacks were not imported'));
    }

    final renamed = context.names.renamedWarning();
    if (renamed != null) warnings.add(renamed);

    return ImportResult(
      source: 'OpenAPI $version spec',
      groups: groups,
      endpoints: endpoints,
      environments: [Environment(id: 'openapi-environment', name: '$apiName (imported)', variables: _ordered(context.variables))],
      warnings: warnings,
    );
  }

  /// `base_url` first, then the variables of paths and parameters, then the (secret)
  /// credentials: what the person has to read, then what they have to fill in.
  Map<String, EnvironmentVariable> _ordered(Map<String, EnvironmentVariable> variables) => {
        for (final entry in variables.entries)
          if (entry.key == 'base_url') entry.key: entry.value,
        for (final entry in variables.entries)
          if (entry.key != 'base_url' && !entry.value.secret) entry.key: entry.value,
        for (final entry in variables.entries)
          if (entry.key != 'base_url' && entry.value.secret) entry.key: entry.value,
      };

  /// `servers[0]` as `base_url` (the first thing the environment has), with the server's
  /// variables filled in by their defaults. Anything odd about the servers is a warning.
  void _defineBaseUrl(OpenApiContext context) {
    final servers = [for (final server in asList(context.document['servers'])) ?asMap(server)];
    if (servers.isEmpty) {
      context.defineVariable('base_url', '');
      context.warnings.add(const ImportWarning(message: 'the file declares no servers; set base_url in the imported environment'));
      return;
    }

    String urlOf(Map<String, dynamic> server) {
      final variables = asMap(server['variables']) ?? const <String, dynamic>{};
      return (asString(server['url']) ?? '').replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (match) {
        final fallback = asMap(variables[match[1]])?['default'];
        return fallback == null ? match[0]! : '$fallback';
      });
    }

    var url = urlOf(servers.first);
    if (!url.contains('://')) {
      context.warnings.add(const ImportWarning(message: 'server URL is relative; set base_url to the host'));
    }
    if (url.length > 1 && url.endsWith('/')) url = url.substring(0, url.length - 1);
    context.defineVariable('base_url', url);

    if (servers.length > 1) {
      context.warnings.add(ImportWarning(message: 'other servers were not imported: ${servers.skip(1).map(urlOf).join(', ')}'));
    }
  }

  /// Every operation of `paths`, in the order of the file, with its first tag.
  List<_Operation> _operations(OpenApiContext context) {
    const methods = {'get', 'put', 'post', 'delete', 'options', 'head', 'patch', 'trace'};
    final operations = <_Operation>[];

    for (final entry in (asMap(context.document['paths']) ?? const <String, dynamic>{}).entries) {
      final item = context.refs.resolve(entry.value, where: entry.key);
      if (item == null) continue;
      final pathParameters = asList(item['parameters']);

      for (final candidate in item.entries) {
        final method = candidate.key.toLowerCase();
        final operation = asMap(candidate.value);
        if (!methods.contains(method) || operation == null) continue;

        String? tag;
        for (final value in asList(operation['tags'])) {
          final name = asString(value)?.trim();
          if (name != null && name.isNotEmpty) {
            tag = name;
            break;
          }
        }
        operations.add(_Operation(entry.key, method, operation, pathParameters, tag));
      }
    }
    return operations;
  }
}

/// One operation found in `paths`.
class _Operation {
  _Operation(this.path, this.method, this.operation, this.pathParameters, this.tag);

  final String path;
  final String method;
  final Map<String, dynamic> operation;
  final List<dynamic> pathParameters;
  final String? tag;
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
