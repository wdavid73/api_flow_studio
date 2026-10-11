import 'package:api_flow_studio/engine/import/import_result.dart';
import 'package:api_flow_studio/engine/import/postman/postman_auth.dart';
import 'package:api_flow_studio/engine/import/postman/postman_request.dart';
import 'package:api_flow_studio/engine/import/postman/postman_variables.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late VariableTranslator translator;
  late List<ImportWarning> warnings;

  setUp(() {
    translator = VariableTranslator();
    warnings = [];
  });

  PostmanAuth? read(Object? auth, {String where = 'Folder'}) =>
      readAuth(auth, where: where, translator: translator, warnings: warnings);

  List<Map<String, Object?>> asList(Map<String, Object?> pairs) => [
        for (final e in pairs.entries) {'key': e.key, 'value': e.value, 'type': 'string'},
      ];

  group('readAuth', () {
    test('no auth, or one with no type, defines nothing: it is inherited', () {
      expect(read(null), isNull);
      expect(read('text'), isNull);
      expect(read(<String, Object?>{}), isNull);
      expect(read({'bearer': asList({'token': 'x'})}), isNull);
      expect(warnings, isEmpty);
    });

    test('noauth is a definition: no authentication, and it stops the inheritance', () {
      final auth = read({'type': 'noauth'})!;

      expect(auth.config, const AuthConfig.none());
      expect(auth.header, isNull);
      expect(auth.queryParam, isNull);
    });

    group('bearer', () {
      test('as a list of key/value, the way Postman exports it', () {
        expect(read({'type': 'bearer', 'bearer': asList({'token': '{{access_token}}'})})!.config, const AuthConfig.bearer(token: '{{access_token}}'));
      });

      test('as a plain object', () {
        expect(read({'type': 'bearer', 'bearer': {'token': 'abc'}})!.config, const AuthConfig.bearer(token: 'abc'));
      });

      test('with no token it is an empty one', () {
        expect(read({'type': 'bearer'})!.config, const AuthConfig.bearer(token: ''));
      });

      test('the variables in the token are translated', () {
        final auth = read({'type': 'bearer', 'bearer': asList({'token': '{{access-token}}'})})!;

        expect(auth.config, const AuthConfig.bearer(token: '{{access_token}}'));
        expect(translator.renamed, {'access-token': 'access_token'});
      });
    });

    group('basic', () {
      test('takes the user name and the password', () {
        expect(read({'type': 'basic', 'basic': asList({'username': 'ana', 'password': 's3cret'})})!.config,
            const AuthConfig.basic(username: 'ana', password: 's3cret'));
      });

      test('with missing parts, empty ones', () {
        expect(read({'type': 'basic', 'basic': asList({'username': 'ana'})})!.config, const AuthConfig.basic(username: 'ana', password: ''));
      });
    });

    group('apikey', () {
      test('in a header is a header', () {
        final auth = read({'type': 'apikey', 'apikey': asList({'key': 'X-Api-Key', 'value': '{{api_key}}', 'in': 'header'})})!;

        expect(auth.config, const AuthConfig.none());
        expect(auth.header, const KeyValueEntry(key: 'X-Api-Key', value: '{{api_key}}'));
        expect(auth.queryParam, isNull);
      });

      test('with no "in" it is a header too', () {
        expect(read({'type': 'apikey', 'apikey': asList({'key': 'X-Key', 'value': 'v'})})!.header, const KeyValueEntry(key: 'X-Key', value: 'v'));
      });

      test('in the query is a query parameter', () {
        final auth = read({'type': 'apikey', 'apikey': asList({'key': 'api_key', 'value': 'v', 'in': 'query'})})!;

        expect(auth.header, isNull);
        expect(auth.queryParam, const KeyValueEntry(key: 'api_key', value: 'v'));
      });

      test('with no key name is unusable: ignored, with a warning', () {
        final auth = read({'type': 'apikey', 'apikey': asList({'value': 'v'})}, where: 'Auth / Login')!;

        expect(auth.header, isNull);
        expect(auth.queryParam, isNull);
        expect(warnings.single.where, 'Auth / Login');
        expect(warnings.single.message, 'api key authentication has no key name; ignored');
      });
    });

    group('types this app has no equivalent for', () {
      test('become no authentication, with a warning at the place that defines them', () {
        for (final type in ['oauth2', 'oauth1', 'digest', 'awsv4', 'hawk', 'ntlm', 'edgegrid', 'something-new']) {
          warnings.clear();

          final auth = read({'type': type, type: asList({'accessToken': 'x'})}, where: 'Orders')!;

          expect(auth.config, const AuthConfig.none(), reason: type);
          expect(warnings, hasLength(1), reason: type);
          expect(warnings.single.where, 'Orders');
          expect(warnings.single.message, 'auth type "$type" is not supported; requests that inherit it have no authentication');
        }
      });
    });

    test('an unknown dynamic variable in a value is reported where the auth is defined', () {
      read({'type': 'bearer', 'bearer': asList({'token': '{{\$randomFirstName}}'})}, where: 'Orders');

      expect(warnings.single.where, 'Orders');
      expect(warnings.single.message, 'unknown dynamic variable {{\$randomFirstName}} left as written');
    });
  });

  group('resolveAuth', () {
    const inherited = PostmanAuth(config: AuthConfig.bearer(token: 'from-parent'));

    PostmanAuth resolve(Object? auth, [PostmanAuth parent = inherited]) =>
        resolveAuth(auth, inherited: parent, where: 'Node', translator: translator, warnings: warnings);

    test('a node with no auth takes the one of its parent', () {
      expect(resolve(null).config, const AuthConfig.bearer(token: 'from-parent'));
    });

    test('its own auth wins over the parent\'s', () {
      expect(resolve({'type': 'basic', 'basic': asList({'username': 'a', 'password': 'b'})}).config, const AuthConfig.basic(username: 'a', password: 'b'));
    });

    test('noauth cuts the inheritance', () {
      expect(resolve({'type': 'noauth'}).config, const AuthConfig.none());
    });

    test('an unsupported type cuts it too (what it replaced is not silently kept)', () {
      expect(resolve({'type': 'oauth2'}).config, const AuthConfig.none());
    });

    test('the top of the tree inherits nothing', () {
      expect(resolveAuth(null, inherited: PostmanAuth.none, where: '', translator: translator, warnings: warnings).config, const AuthConfig.none());
    });

    test('an api key from a parent is inherited whole', () {
      const key = PostmanAuth(config: AuthConfig.none(), header: KeyValueEntry(key: 'X-Key', value: 'v'));

      expect(resolve(null, key).header, const KeyValueEntry(key: 'X-Key', value: 'v'));
    });

    test('a warning is given where the auth is defined, not for each node that inherits it', () {
      final collectionAuth = resolve({'type': 'oauth2'}, PostmanAuth.none);
      final warningsAtDefinition = warnings.length;

      resolve(null, collectionAuth);
      resolve(null, collectionAuth);

      expect(warningsAtDefinition, 1);
      expect(warnings, hasLength(1));
    });
  });

  group('on a request', () {
    Endpoint build(Map<String, dynamic> request, PostmanAuth auth) => requestToEndpoint(
          item: {'name': 'R', 'request': request},
          id: 'e',
          groupId: 'g',
          path: 'Folder / R',
          translator: translator,
          warnings: warnings,
          auth: auth,
        );

    test('bearer and basic become the request\'s authentication', () {
      expect(build({'url': 'https://x.test'}, const PostmanAuth(config: AuthConfig.bearer(token: 't'))).authConfig, const AuthConfig.bearer(token: 't'));
      expect(build({'url': 'https://x.test'}, const PostmanAuth(config: AuthConfig.basic(username: 'u', password: 'p'))).authConfig,
          const AuthConfig.basic(username: 'u', password: 'p'));
    });

    test('an api key header is added after the request\'s own headers', () {
      final endpoint = build({
        'url': 'https://x.test',
        'header': [
          {'key': 'Accept', 'value': 'application/json'},
        ],
      }, const PostmanAuth(config: AuthConfig.none(), header: KeyValueEntry(key: 'X-Key', value: 'v')));

      expect(endpoint.headers.map((h) => h.key), ['Accept', 'X-Key']);
      expect(endpoint.authConfig, const AuthConfig.none());
    });

    test('an api key query parameter is added after the request\'s own', () {
      final endpoint = build({'url': 'https://x.test/a?page=1'}, const PostmanAuth(config: AuthConfig.none(), queryParam: KeyValueEntry(key: 'api_key', value: 'v')));

      expect(endpoint.queryParams.map((p) => p.key), ['page', 'api_key']);
    });

    test('no auth is the default', () {
      expect(build({'url': 'https://x.test'}, PostmanAuth.none).authConfig, const AuthConfig.none());
    });
  });
}
