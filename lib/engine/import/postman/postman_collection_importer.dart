import '../../models/models.dart';
import '../foreign_variables.dart';
import '../import_result.dart';
import '../import_source.dart';
import '../importer.dart';
import 'postman_auth.dart';
import '../import_json.dart';
import 'postman_request.dart';
import 'postman_variables.dart';

/// A Postman collection (v2.0 or v2.1): `{info, item: [...], auth, variable, event}`.
/// It becomes a root folder named after the collection with the same tree below it,
/// and an environment `<name> (imported)` with the collection's variables.
///
/// Nothing in it is run, and nothing it mentions is fetched or read: scripts are only
/// reported. Whatever cannot be carried over is a warning, located by the path of the
/// folder or request it was in.
class PostmanCollectionImporter implements Importer {
  const PostmanCollectionImporter();

  @override
  String get formatName => 'Postman collection';

  @override
  List<String> get extensions => const ['json'];

  @override
  bool matches(ImportSource source) {
    final json = asMap(source.json);
    if (json == null) return false;
    if (json['info'] is Map) return json['item'] is List;
    return _isV1(json);
  }

  /// Version 1 has `requests` and `folders` at the top and no `info`.
  static bool _isV1(Map<String, dynamic> json) =>
      json['requests'] is List && (json.containsKey('folders') || json.containsKey('order') || json.containsKey('id'));

  @override
  ImportResult parse(ImportSource source) {
    final json = asMap(source.json)!;
    if (json['info'] is! Map) {
      throw const ImportException('That is a Postman collection v1, which is not supported. Export it again as v2.1.');
    }
    return _Walk(json).run();
  }
}

/// How deep folders may nest before the rest is left out (a guard against a malicious
/// or broken file, not a limit anyone meets).
const int _maxDepth = 50;

/// One pass over a collection, collecting folders, requests, variables and warnings.
class _Walk {
  _Walk(this.json);

  final Map<String, dynamic> json;
  final translator = VariableTranslator();
  final warnings = <ImportWarning>[];
  final groups = <Group>[];
  final endpoints = <Endpoint>[];
  final variables = <String, EnvironmentVariable>{};
  final disabledVariables = <String>[];
  var examples = 0;
  var tooDeepReported = false;
  var _groupCount = 0;
  var _endpointCount = 0;

  String _groupId() => 'postman-group-${++_groupCount}';
  String _endpointId() => 'postman-request-${++_endpointCount}';

  ImportResult run() {
    final info = asMap(json['info'])!;
    final name = (asString(info['name']) ?? '').trim();
    final collectionName = name.isEmpty ? 'Postman collection' : name;

    final root = Group(id: _groupId(), name: collectionName);
    groups.add(root);

    _scripts(json['event'], 'Collection');
    _variables(json['variable'], where: '', isFolder: false);
    final auth = resolveAuth(json['auth'], inherited: PostmanAuth.none, where: 'Collection', translator: translator, warnings: warnings);
    _items(json['item'], root.id, const [], auth, 1);

    if (disabledVariables.isNotEmpty) {
      warnings.add(ImportWarning(message: 'disabled variables were left out: ${disabledVariables.join(', ')}'));
    }
    if (examples > 0) {
      warnings.add(ImportWarning(
        message: examples == 1 ? '1 saved example response was not imported' : '$examples saved example responses were not imported',
      ));
    }
    final renamed = translator.renamedWarning();
    if (renamed != null) warnings.add(renamed);
    warnings.addAll(undefinedVariableWarnings(endpoints, variables.keys.toSet()));

    return ImportResult(
      source: 'Postman collection',
      groups: groups,
      endpoints: endpoints,
      environments: [
        if (variables.isNotEmpty) Environment(id: 'postman-environment', name: '$collectionName (imported)', variables: variables),
      ],
      warnings: warnings,
    );
  }

  void _items(Object? list, String parentId, List<String> pathParts, PostmanAuth inherited, int depth) {
    var folderOrder = 0;
    for (final raw in asList(list)) {
      final item = asMap(raw);
      if (item == null) continue;
      final name = (asString(item['name']) ?? '').trim();

      if (item['item'] is List) {
        if (depth > _maxDepth) {
          if (!tooDeepReported) {
            tooDeepReported = true;
            warnings.add(const ImportWarning(message: 'folders nested deeper than $_maxDepth levels were left out'));
          }
          continue;
        }
        final folderName = name.isEmpty ? 'Folder' : name;
        final path = [...pathParts, folderName];
        final where = path.join(' / ');
        final id = _groupId();
        groups.add(Group(id: id, name: folderName, parentGroupId: parentId, order: folderOrder++));

        _scripts(item['event'], where);
        _variables(item['variable'], where: where, isFolder: true);
        final auth = resolveAuth(item['auth'], inherited: inherited, where: where, translator: translator, warnings: warnings);
        _items(item['item'], id, path, auth, depth + 1);
      } else if (item.containsKey('request')) {
        final where = [...pathParts, name.isEmpty ? '(unnamed request)' : name].join(' / ');
        final request = asMap(item['request']);
        _scripts(item['event'], where);
        examples += asList(item['response']).length;

        final auth = resolveAuth(request?['auth'] ?? item['auth'], inherited: inherited, where: where, translator: translator, warnings: warnings);
        endpoints.add(requestToEndpoint(
          item: item,
          id: _endpointId(),
          groupId: parentId,
          path: where,
          translator: translator,
          warnings: warnings,
          auth: auth,
        ));
      } else {
        final where = [...pathParts, name.isEmpty ? '(unnamed item)' : name].join(' / ');
        warnings.add(ImportWarning(where: where, message: 'it has neither a request nor items; skipped'));
      }
    }
  }

  /// One warning per kind of script (pre-request, test) a node defines, if it has any code.
  void _scripts(Object? events, String where) {
    final seen = <String>{};
    for (final event in asList(events)) {
      final map = asMap(event);
      final listen = map == null ? null : asString(map['listen']);
      final exec = asMap(map?['script'])?['exec'];
      final hasCode = exec is List ? exec.any((line) => line is String && line.trim().isNotEmpty) : exec is String && exec.trim().isNotEmpty;
      if (listen == null || !hasCode || !seen.add(listen)) continue;
      final label = listen == 'prerequest' ? 'pre-request' : listen;
      warnings.add(ImportWarning(where: where, message: '$label script ignored'));
    }
  }

  /// The `variable` list of the collection or a folder, into the one environment.
  void _variables(Object? list, {required String where, required bool isFolder}) {
    var any = false;
    for (final entry in asList(list)) {
      final map = asMap(entry);
      final key = map == null ? null : asString(map['key']);
      if (map == null || key == null || key.isEmpty) continue;
      any = true;

      if (map['disabled'] == true) {
        disabledVariables.add(key);
        continue;
      }
      final name = translator.sanitizeName(key);
      if (variables.containsKey(name)) {
        warnings.add(ImportWarning(where: where.isEmpty ? key : where, message: 'variable "$name" is defined more than once; the first value was kept'));
        continue;
      }
      final unknown = <String>[];
      final value = translator.translate(map['value'] == null ? '' : '${map['value']}', unknownDynamic: unknown);
      warnings.addAll(unknownDynamicWarnings(where.isEmpty ? key : where, unknown));
      variables[name] = EnvironmentVariable(value: value, secret: map['type'] == 'secret');
    }
    if (isFolder && any) {
      warnings.add(ImportWarning(
        where: where,
        message: 'variables defined on this folder were added to the imported environment (they are not scoped to the folder here)',
      ));
    }
  }
}
