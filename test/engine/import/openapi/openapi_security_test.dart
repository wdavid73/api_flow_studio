import 'dart:convert';

import 'package:api_flow_studio/engine/import/import_result.dart';
import 'package:api_flow_studio/engine/import/import_source.dart';
import 'package:api_flow_studio/engine/import/openapi/openapi_importer.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const importer = OpenApiImporter();

  Map<String, Object?> operation({Object? security = _unset, String summary = 'op'}) => {
        'summary': summary,
        'responses': {'200': {'description': 'ok'}},
        if (!identical(security, _unset)) 'security': security,
      };

  ImportResult parse({
    Map<String, Object?> schemes = const {},
    Object? global,
    Map<String, Map<String, Object?>>? paths,
  }) =>
      importer.parse(ImportSource(jsonEncode({
        'openapi': '3.0.3',
        'info': {'title': 'T', 'version': '1'},
        'servers': [{'url': 'https://x.test'}],
        'security': ?global,
        'paths': paths ?? {'/a': {'get': operation()}},
        'components': {'securitySchemes': schemes},
      })));

  const bearer = {'type': 'http', 'scheme': 'bearer', 'bearerFormat': 'JWT'};
  const basic = {'type': 'http', 'scheme': 'basic'};

  Endpoint only(ImportResult r) => r.endpoints.single;
  Iterable<String> messages(ImportResult r) => r.warnings.map((w) => w.message);

  group('bearer and basic', () {
    test('bearer is the token variable of its scheme', () {
      final result = parse(schemes: {'BearerAuth': bearer}, global: [{'BearerAuth': <String>[]}]);

      expect(only(result).authConfig, const AuthConfig.bearer(token: '{{BearerAuth_token}}'));
      expect(result.warnings, isEmpty);
    });

    test('basic is the username and password variables of its scheme', () {
      final result = parse(schemes: {'basicAuth': basic}, global: [{'basicAuth': <String>[]}]);

      expect(only(result).authConfig, const AuthConfig.basic(username: '{{basicAuth_username}}', password: '{{basicAuth_password}}'));
    });

    test('the scheme name of http is not case sensitive', () {
      final result = parse(schemes: {'A': {'type': 'http', 'scheme': 'Bearer'}}, global: [{'A': <String>[]}]);

      expect(only(result).authConfig, const AuthConfig.bearer(token: '{{A_token}}'));
    });

    test('the variables are in the environment, secret and empty', () {
      final env = parse(schemes: {'BearerAuth': bearer, 'basicAuth': basic}, global: [{'BearerAuth': <String>[]}, {'basicAuth': <String>[]}]).environments.single;

      expect(env.variables['BearerAuth_token']!.secret, isTrue);
      expect(env.variables['BearerAuth_token']!.value, '');
      // Only the scheme a request uses (the first alternative) is defined.
      expect(env.variables.containsKey('basicAuth_username'), isFalse);
    });
  });

  group('api keys', () {
    test('in a header is a header whose value is the scheme\'s variable', () {
      final result = parse(
        schemes: {'ApiKey': {'type': 'apiKey', 'in': 'header', 'name': 'X-Api-Key'}},
        global: [{'ApiKey': <String>[]}],
      );

      expect(only(result).headers, const [KeyValueEntry(key: 'X-Api-Key', value: '{{ApiKey}}')]);
      expect(only(result).authConfig, const AuthConfig.none());
      expect(result.environments.single.variables['ApiKey']!.secret, isTrue);
    });

    test('in the query is a query parameter', () {
      final result = parse(
        schemes: {'ApiKey': {'type': 'apiKey', 'in': 'query', 'name': 'api_key'}},
        global: [{'ApiKey': <String>[]}],
      );

      expect(only(result).queryParams, const [KeyValueEntry(key: 'api_key', value: '{{ApiKey}}')]);
    });

    test('in a cookie is not supported', () {
      final result = parse(
        schemes: {'Session': {'type': 'apiKey', 'in': 'cookie', 'name': 'sid'}},
        global: [{'Session': <String>[]}],
      );

      expect(only(result).headers, isEmpty);
      expect(only(result).authConfig, const AuthConfig.none());
      expect(result.warnings.single.where, 'components.securitySchemes.Session');
      expect(result.warnings.single.message, 'security scheme "Session" (apiKey in a cookie) is not supported; requests that use it have no authentication');
    });

    test('with no name there is nothing to send', () {
      final result = parse(schemes: {'K': {'type': 'apiKey', 'in': 'header'}}, global: [{'K': <String>[]}]);

      expect(only(result).headers, isEmpty);
    });
  });

  group('types with no equivalent here', () {
    test('give no authentication, with one warning per scheme however many requests use it', () {
      final result = parse(
        schemes: {
          'oauth': {'type': 'oauth2', 'flows': <String, Object?>{}},
          'oidc': {'type': 'openIdConnect', 'openIdConnectUrl': 'https://x.test/.well-known'},
          'mtls': {'type': 'mutualTLS'},
          'digest': {'type': 'http', 'scheme': 'digest'},
        },
        global: [{'oauth': ['read']}],
        paths: {
          '/a': {'get': operation(), 'post': operation()},
          '/b': {
            'get': operation(security: [{'oidc': <String>[]}]),
            'put': operation(security: [{'mtls': <String>[]}]),
            'delete': operation(security: [{'digest': <String>[]}]),
          },
        },
      );

      expect(result.endpoints.every((e) => e.authConfig == const AuthConfig.none()), isTrue);
      final warned = {for (final w in result.warnings.where((w) => w.message.startsWith('security scheme'))) w.where: w.message};
      expect(warned, {
        'components.securitySchemes.oauth': 'security scheme "oauth" (oauth2) is not supported; requests that use it have no authentication',
        'components.securitySchemes.oidc': 'security scheme "oidc" (openIdConnect) is not supported; requests that use it have no authentication',
        'components.securitySchemes.mtls': 'security scheme "mtls" (mutualTLS) is not supported; requests that use it have no authentication',
        'components.securitySchemes.digest': 'security scheme "digest" (http digest) is not supported; requests that use it have no authentication',
      });
      expect(result.warnings.where((w) => w.message.startsWith('security scheme')), hasLength(4));
    });

    test('define no variable', () {
      final result = parse(schemes: {'oauth': {'type': 'oauth2'}}, global: [{'oauth': <String>[]}]);

      expect(result.environments.single.variables.keys, ['base_url']);
    });

    test('a scheme that is not defined at all is warned about, once', () {
      final result = parse(
        global: [{'Ghost': <String>[]}],
        paths: {'/a': {'get': operation(), 'post': operation()}},
      );

      expect(messages(result).where((m) => m.contains('Ghost')), ['security scheme "Ghost" is not defined; ignored']);
    });
  });

  group('which security applies to an operation', () {
    test('the global one, unless the operation has its own', () {
      final result = parse(
        schemes: {'A': bearer, 'B': basic},
        global: [{'A': <String>[]}],
        paths: {
          '/a': {
            'get': operation(summary: 'global'),
            'post': operation(summary: 'own', security: [{'B': <String>[]}]),
          },
        },
      );

      final auth = {for (final e in result.endpoints) e.name: e.authConfig};
      expect(auth['global'], const AuthConfig.bearer(token: '{{A_token}}'));
      expect(auth['own'], const AuthConfig.basic(username: '{{B_username}}', password: '{{B_password}}'));
    });

    test('an empty list on the operation means none, whatever the global says', () {
      final result = parse(schemes: {'A': bearer}, global: [{'A': <String>[]}], paths: {'/a': {'get': operation(security: <Object?>[])}});

      expect(only(result).authConfig, const AuthConfig.none());
    });

    test('with no security anywhere there is none', () {
      expect(only(parse(schemes: {'A': bearer})).authConfig, const AuthConfig.none());
    });

    test('of several alternatives (OR) the first that is not empty is used', () {
      final result = parse(
        schemes: {'A': bearer, 'B': basic},
        global: [<String, Object?>{}, {'B': <String>[]}, {'A': <String>[]}],
      );

      expect(only(result).authConfig, const AuthConfig.basic(username: '{{B_username}}', password: '{{B_password}}'));
    });

    test('only empty alternatives mean none', () {
      expect(only(parse(schemes: {'A': bearer}, global: [<String, Object?>{}])).authConfig, const AuthConfig.none());
    });

    test('security that is not a list is ignored', () {
      expect(only(parse(schemes: {'A': bearer}, global: 'nope')).authConfig, const AuthConfig.none());
    });
  });

  group('several schemes together (AND)', () {
    test('an api key header and an api key query are both applied', () {
      final result = parse(
        schemes: {
          'H': {'type': 'apiKey', 'in': 'header', 'name': 'X-Key'},
          'Q': {'type': 'apiKey', 'in': 'query', 'name': 'key'},
        },
        global: [{'H': <String>[], 'Q': <String>[]}],
      );

      expect(only(result).headers.map((h) => h.key), ['X-Key']);
      expect(only(result).queryParams.map((p) => p.key), ['key']);
    });

    test('a key and a bearer token go together', () {
      final result = parse(
        schemes: {'H': {'type': 'apiKey', 'in': 'header', 'name': 'X-Key'}, 'A': bearer},
        global: [{'H': <String>[], 'A': <String>[]}],
      );

      expect(only(result).headers.map((h) => h.key), ['X-Key']);
      expect(only(result).authConfig, const AuthConfig.bearer(token: '{{A_token}}'));
    });

    test('two that want the same place (bearer and basic): the first, with a warning', () {
      final result = parse(
        schemes: {'A': bearer, 'B': basic},
        global: [{'A': <String>[], 'B': <String>[]}],
      );

      expect(only(result).authConfig, const AuthConfig.bearer(token: '{{A_token}}'));
      expect(result.warnings.single.where, 'GET /a');
      expect(result.warnings.single.message, 'only the first of several authentication schemes was applied');
    });
  });

  group('references and names', () {
    test('a scheme given as a reference is followed', () {
      final result = parse(
        schemes: {
          'Alias': {r'$ref': '#/components/securitySchemes/Real'},
          'Real': bearer,
        },
        global: [{'Alias': <String>[]}],
      );

      expect(only(result).authConfig, const AuthConfig.bearer(token: '{{Alias_token}}'));
    });

    test('a scheme name that cannot be a variable is renamed, and the file says so once', () {
      final result = parse(schemes: {'my-bearer.auth': bearer}, global: [{'my-bearer.auth': <String>[]}]);

      expect(only(result).authConfig, const AuthConfig.bearer(token: '{{my_bearer_auth_token}}'));
      expect(result.environments.single.variables.keys, contains('my_bearer_auth_token'));
      expect(messages(result).where((m) => m.startsWith('variable names changed')), hasLength(1));
    });

    test('the same scheme used by many requests defines its variable once, after the ones of paths and parameters', () {
      final result = parse(
        schemes: {'A': bearer},
        global: [{'A': <String>[]}],
        paths: {'/a/{id}': {'get': operation(), 'post': operation()}},
      );

      expect(result.environments.single.variables.keys, ['base_url', 'id', 'A_token']);
    });
    group('a name two things want', () {
    test('a credential stays secret when a parameter of the same name defined the variable first', () {
      final result = parse(
        schemes: {'api_key': {'type': 'apiKey', 'name': 'X-Key', 'in': 'header'}},
        paths: {
          '/a': {
            'get': {
              ...operation(security: [{'api_key': <String>[]}]),
              'parameters': [
                {'name': 'api_key', 'in': 'query', 'required': true, 'schema': {'type': 'string'}},
              ],
            },
          },
        },
      );

      final variable = result.environments.single.variables['api_key']!;
      expect(variable.secret, isTrue);
      expect(variable.value, isEmpty);
    });
  });
});
}

const Object _unset = Object();
