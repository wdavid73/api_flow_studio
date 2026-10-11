import '../../models/models.dart';
import '../import_json.dart';
import '../import_result.dart';
import 'openapi_context.dart';

/// The authentication an operation ends up with. This app has bearer and basic as request
/// settings; an API key is just a header or a query parameter, so it is added as one.
typedef OpenApiAuth = ({AuthConfig config, KeyValueEntry? header, KeyValueEntry? query});

const OpenApiAuth noOpenApiAuth = (config: AuthConfig.none(), header: null, query: null);

/// The authentication of [operation]: its own `security`, else the document's. Of the
/// alternatives (OR) the first that is not empty is used; the schemes of one alternative
/// (AND) are all applied. The credentials are variables of the environment (secret, empty)
/// named after the scheme, so the file never carries a secret and nothing is invented.
OpenApiAuth readSecurity({required Map<String, dynamic> operation, required OpenApiContext context, required String where}) {
  final security = operation.containsKey('security') ? operation['security'] : context.document['security'];
  if (security is! List) return noOpenApiAuth;

  Map<String, dynamic>? requirement;
  for (final alternative in security) {
    final map = asMap(alternative);
    if (map != null && map.isNotEmpty) {
      requirement = map;
      break;
    }
  }
  if (requirement == null) return noOpenApiAuth;

  final schemes = asMap(asMap(context.document['components'])?['securitySchemes']) ?? const <String, dynamic>{};
  AuthConfig config = const AuthConfig.none();
  var configTaken = false;
  KeyValueEntry? header;
  KeyValueEntry? query;

  String secret(String name) {
    final variable = context.names.sanitize(name);
    context.defineVariable(variable, '', secret: true);
    return '{{$variable}}';
  }

  for (final name in requirement.keys) {
    final scheme = context.refs.resolve(schemes[name], where: 'components.securitySchemes.$name');
    if (scheme == null) {
      if (!schemes.containsKey(name) && context.warnedSchemes.add('undefined|$name')) {
        context.warnings.add(ImportWarning(message: 'security scheme "$name" is not defined; ignored'));
      }
      continue;
    }

    final type = asString(scheme['type']);
    switch (type) {
      case 'http':
        final kind = (asString(scheme['scheme']) ?? '').toLowerCase();
        if (kind != 'bearer' && kind != 'basic') {
          _unsupported(context, name, 'http $kind');
        } else if (configTaken) {
          context.warnings.add(ImportWarning(where: where, message: 'only the first of several authentication schemes was applied'));
        } else {
          configTaken = true;
          config = kind == 'bearer'
              ? AuthConfig.bearer(token: secret('${name}_token'))
              : AuthConfig.basic(username: secret('${name}_username'), password: secret('${name}_password'));
        }
      case 'apiKey':
        final keyName = asString(scheme['name']);
        final place = asString(scheme['in']);
        if (place == 'cookie') {
          _unsupported(context, name, 'apiKey in a cookie');
        } else if (keyName != null && keyName.isNotEmpty) {
          final entry = KeyValueEntry(key: keyName, value: secret(name));
          if (place == 'query') {
            query = entry;
          } else {
            header = entry;
          }
        }
      default:
        _unsupported(context, name, type ?? 'unknown');
    }
  }
  return (config: config, header: header, query: query);
}

/// One warning per scheme, however many operations use it, located where it is defined.
void _unsupported(OpenApiContext context, String name, String kind) {
  if (!context.warnedSchemes.add('unsupported|$name')) return;
  context.warnings.add(ImportWarning(
    where: 'components.securitySchemes.$name',
    message: 'security scheme "$name" ($kind) is not supported; requests that use it have no authentication',
  ));
}
