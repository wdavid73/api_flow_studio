import '../../models/models.dart';
import '../import_result.dart';
import 'postman_json.dart';
import 'postman_variables.dart';

/// The authentication a Postman node ends up with. This app has bearer and basic as
/// request settings; an API key is just a header or a query parameter, so it travels
/// as one of those and the request gets it added.
class PostmanAuth {
  const PostmanAuth({required this.config, this.header, this.queryParam});

  final AuthConfig config;
  final KeyValueEntry? header;
  final KeyValueEntry? queryParam;

  /// No authentication at all (also what `noauth` and unsupported types give).
  static const PostmanAuth none = PostmanAuth(config: AuthConfig.none());
}

/// The auth a node (collection, folder or request) *defines*, or null when it defines
/// none and so inherits its parent's. `noauth` is a definition: it stops the
/// inheritance. A type with no equivalent here gives no authentication and a warning
/// located at [where], the node that defines it.
PostmanAuth? readAuth(
  Object? auth, {
  required String where,
  required VariableTranslator translator,
  required List<ImportWarning> warnings,
}) {
  final map = asMap(auth);
  final type = map == null ? null : asString(map['type']);
  if (map == null || type == null || type.isEmpty) return null;

  final unknown = <String>[];
  final params = _params(map[type]);
  String value(String name) => translator.translate(params[name] ?? '', unknownDynamic: unknown);

  final PostmanAuth result;
  switch (type) {
    case 'noauth':
      result = PostmanAuth.none;
    case 'bearer':
      result = PostmanAuth(config: AuthConfig.bearer(token: value('token')));
    case 'basic':
      result = PostmanAuth(config: AuthConfig.basic(username: value('username'), password: value('password')));
    case 'apikey':
      final key = value('key');
      if (key.isEmpty) {
        warnings.add(ImportWarning(where: where, message: 'api key authentication has no key name; ignored'));
        result = PostmanAuth.none;
      } else if (params['in'] == 'query') {
        result = PostmanAuth(config: AuthConfig.none(), queryParam: KeyValueEntry(key: key, value: value('value')));
      } else {
        result = PostmanAuth(config: AuthConfig.none(), header: KeyValueEntry(key: key, value: value('value')));
      }
    default:
      warnings.add(ImportWarning(
        where: where,
        message: 'auth type "$type" is not supported; requests that inherit it have no authentication',
      ));
      result = PostmanAuth.none;
  }

  warnings.addAll(unknownDynamicWarnings(where, unknown));
  return result;
}

/// What a node's auth is: its own definition, or [inherited] from above. Warnings are
/// only given by a node that defines one, so a collection-level OAuth is reported once,
/// not by each request under it.
PostmanAuth resolveAuth(
  Object? auth, {
  required PostmanAuth inherited,
  required String where,
  required VariableTranslator translator,
  required List<ImportWarning> warnings,
}) =>
    readAuth(auth, where: where, translator: translator, warnings: warnings) ?? inherited;

/// The `[{key, value}]` list Postman exports (or a plain `{key: value}` object) as a map.
Map<String, String> _params(Object? value) {
  final params = <String, String>{};
  if (value is List) {
    for (final entry in value) {
      final map = asMap(entry);
      final key = map == null ? null : asString(map['key']);
      if (key != null) params[key] = map!['value'] == null ? '' : '${map['value']}';
    }
  } else if (value is Map) {
    value.forEach((key, v) => params['$key'] = v == null ? '' : '$v');
  }
  return params;
}
