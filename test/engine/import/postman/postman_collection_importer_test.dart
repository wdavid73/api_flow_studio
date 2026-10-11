import 'dart:convert';
import 'dart:io';

import 'package:api_flow_studio/engine/import/import_registry.dart';
import 'package:api_flow_studio/engine/import/import_result.dart';
import 'package:api_flow_studio/engine/import/import_source.dart';
import 'package:api_flow_studio/engine/import/importer.dart';
import 'package:api_flow_studio/engine/import/postman/postman_collection_importer.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> collection({
  String? name = 'My API',
  List<Object?> items = const [],
  Object? auth,
  List<Object?>? variables,
  List<Object?>? events,
  String schema = 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
}) =>
    {
      'info': {'name': ?name, 'schema': schema},
      'item': items,
      'auth': ?auth,
      'variable': ?variables,
      'event': ?events,
    };

Map<String, Object?> request(String name, {Object? url = 'https://x.test', Map<String, Object?> extra = const {}, List<Object?>? events}) => {
      'name': name,
      'request': {'method': 'GET', 'url': url, ...extra},
      'event': ?events,
    };

Map<String, Object?> folder(String name, List<Object?> items, {Object? auth, List<Object?>? variables, List<Object?>? events}) => {
      'name': name,
      'item': items,
      'auth': ?auth,
      'variable': ?variables,
      'event': ?events,
    };

Map<String, Object?> bearer(String token) => {'type': 'bearer', 'bearer': [{'key': 'token', 'value': token}]};

Map<String, Object?> script(String listen, [List<String> lines = const ['console.log(1);']]) => {'listen': listen, 'script': {'exec': lines}};

void main() {
  const importer = PostmanCollectionImporter();

  ImportResult parse(Object json) => importer.parse(ImportSource(jsonEncode(json)));
  bool matches(Object json) => importer.matches(ImportSource(jsonEncode(json)));
  Iterable<String> messages(ImportResult r) => r.warnings.map((w) => w.message);

  group('matches', () {
    test('a v2.1 and a v2.0 collection', () {
      expect(matches(collection()), isTrue);
      expect(matches(collection(schema: 'https://schema.getpostman.com/json/collection/v2.0.0/collection.json')), isTrue);
    });

    test('a collection whose info has no schema', () {
      expect(matches({'info': {'name': 'x'}, 'item': []}), isTrue);
    });

    test('a v1 collection (so it can be explained)', () {
      expect(matches({'id': 'abc', 'name': 'Old', 'order': [], 'folders': [], 'requests': []}), isTrue);
    });

    test('not the other formats, text or nothing', () {
      expect(matches({'name': 'Staging', 'values': [], '_postman_variable_scope': 'environment'}), isFalse);
      expect(matches({'groups': [], 'endpoints': []}), isFalse);
      expect(matches({'openapi': '3.0.0', 'info': {'title': 'x'}, 'paths': {}}), isFalse);
      expect(matches({'info': {'name': 'x'}}), isFalse);
      expect(matches({'item': []}), isFalse);
      expect(matches(['info']), isFalse);
      expect(importer.matches(ImportSource('not json')), isFalse);
      expect(importer.matches(ImportSource('')), isFalse);
    });
  });

  group('the tree', () {
    test('the collection is a root folder named after it, with its folders and requests below', () {
      final result = parse(collection(items: [
        request('Health'),
        folder('Auth', [request('Login'), folder('Tokens', [request('Refresh')])]),
      ]));

      expect(result.source, 'Postman collection');
      expect(result.groups.map((g) => g.name), ['My API', 'Auth', 'Tokens']);
      final root = result.groups[0];
      final auth = result.groups[1];
      final tokens = result.groups[2];
      expect(root.parentGroupId, isNull);
      expect(auth.parentGroupId, root.id);
      expect(tokens.parentGroupId, auth.id);
      final byName = {for (final e in result.endpoints) e.name: e};
      expect(byName['Health']!.groupId, root.id);
      expect(byName['Login']!.groupId, auth.id);
      expect(byName['Refresh']!.groupId, tokens.id);
    });

    test('requests keep the order of the file, and folders their order among siblings', () {
      final result = parse(collection(items: [
        folder('B', [request('b2'), request('b1')]),
        request('Top'),
        folder('A', [request('a1')]),
      ]));

      expect(result.endpoints.map((e) => e.name), ['b2', 'b1', 'Top', 'a1']);
      expect(result.groups.where((g) => g.parentGroupId != null).map((g) => '${g.name}:${g.order}'), ['B:0', 'A:1']);
    });

    test('every id is its own, and every request points at a folder of the result', () {
      final result = parse(collection(items: [folder('A', [request('one'), request('two')]), request('three')]));

      final groupIds = result.groups.map((g) => g.id).toSet();
      expect(groupIds, hasLength(result.groups.length));
      expect(result.endpoints.map((e) => e.id).toSet(), hasLength(3));
      expect(result.endpoints.every((e) => groupIds.contains(e.groupId)), isTrue);
    });

    test('with no collection name, a default; with no folder name, "Folder"', () {
      expect(parse(collection(name: null, items: [request('r')])).groups.single.name, 'Postman collection');
      expect(parse(collection(items: [folder('  ', [request('r')])])).groups.last.name, 'Folder');
    });

    test('an item that is neither a request nor a folder is skipped, with a warning', () {
      final result = parse(collection(items: [
        folder('Stuff', [
          {'name': 'Nothing here'},
          request('Real'),
        ]),
        'junk',
      ]));

      expect(result.endpoints.map((e) => e.name), ['Real']);
      expect(result.warnings.map((w) => '${w.where}: ${w.message}'), contains('Stuff / Nothing here: it has neither a request nor items; skipped'));
    });

    test('folders nested deeper than 50 levels are left out, with a warning', () {
      Object? nested = request('Deep request');
      for (var i = 0; i < 60; i++) {
        nested = folder('Level $i', [nested]);
      }

      final result = parse(collection(items: [nested]));

      expect(result.groups.length, lessThanOrEqualTo(52));
      expect(messages(result), contains('folders nested deeper than 50 levels were left out'));
    });

    test('a collection with only an empty list of items has no requests', () {
      final result = parse(collection());

      expect(result.endpoints, isEmpty);
    });
  });

  group('what is ignored', () {
    test('a script is reported where it is defined, one warning per kind per place', () {
      final result = parse(collection(
        events: [script('prerequest'), script('test')],
        items: [
          folder('Orders', [
            request('Create', events: [script('prerequest'), script('prerequest', ['other();'])]),
            request('List'),
          ], events: [script('test')]),
        ],
      ));

      expect(result.warnings.map((w) => '${w.where}: ${w.message}').toList(), containsAll([
        'Collection: pre-request script ignored',
        'Collection: test script ignored',
        'Orders: test script ignored',
        'Orders / Create: pre-request script ignored',
      ]));
      expect(messages(result).where((m) => m.contains('pre-request')), hasLength(2));
    });

    test('an empty script is not worth a warning', () {
      final result = parse(collection(events: [script('prerequest', []), script('test', ['', '   '])], items: [request('r')]));

      expect(messages(result).where((m) => m.contains('script')), isEmpty);
    });

    test('a script given as text is read too', () {
      final result = parse(collection(events: [{'listen': 'prerequest', 'script': {'exec': 'pm.test();'}}], items: [request('r')]));

      expect(messages(result), contains('pre-request script ignored'));
    });

    test('saved example responses are counted in one warning', () {
      final result = parse(collection(items: [
        {
          ...request('a'),
          'response': [{'name': 'one'}, {'name': 'two'}],
        },
        folder('F', [
          {
            ...request('b'),
            'response': [{'name': 'three'}],
          },
        ]),
      ]));

      expect(result.warnings.where((w) => w.message.contains('saved example')).map((w) => w.message), ['3 saved example responses were not imported']);
    });

    test('one saved example is worded in the singular', () {
      final result = parse(collection(items: [
        {
          ...request('a'),
          'response': [{'name': 'one'}],
        },
      ]));

      expect(messages(result), contains('1 saved example response was not imported'));
    });
  });

  group('authentication', () {
    test('is inherited from the collection and from folders, and a request can have its own', () {
      final result = parse(collection(
        auth: bearer('top'),
        items: [
          request('Plain'),
          folder('Basics', [
            request('Inherits folder'),
            request('Own', extra: {'auth': bearer('own')}),
          ], auth: bearer('folder')),
        ],
      ));

      final auth = {for (final e in result.endpoints) e.name: e.authConfig};
      expect(auth['Plain'], const AuthConfig.bearer(token: 'top'));
      expect(auth['Inherits folder'], const AuthConfig.bearer(token: 'folder'));
      expect(auth['Own'], const AuthConfig.bearer(token: 'own'));
    });

    test('noauth on a folder cuts the inheritance for everything under it', () {
      final result = parse(collection(auth: bearer('top'), items: [folder('Public', [request('Open'), folder('Deeper', [request('Still open')])], auth: {'type': 'noauth'})]));

      expect(result.endpoints.every((e) => e.authConfig == const AuthConfig.none()), isTrue);
    });

    test('an unsupported type is warned once at its definition, not for every request below it', () {
      final result = parse(collection(auth: {'type': 'oauth2', 'oauth2': []}, items: [request('a'), request('b'), folder('F', [request('c')])]));

      final authWarnings = result.warnings.where((w) => w.message.startsWith('auth type'));
      expect(authWarnings, hasLength(1));
      expect(authWarnings.single.where, 'Collection');
      expect(result.endpoints.every((e) => e.authConfig == const AuthConfig.none()), isTrue);
    });

    test('the auth of a request under a folder with a different one wins for it only', () {
      final result = parse(collection(
        auth: bearer('top'),
        items: [
          folder('F', [request('Under F')], auth: {'type': 'basic', 'basic': [{'key': 'username', 'value': 'u'}, {'key': 'password', 'value': 'p'}]}),
          request('After F'),
        ],
      ));

      final auth = {for (final e in result.endpoints) e.name: e.authConfig};
      expect(auth['Under F'], const AuthConfig.basic(username: 'u', password: 'p'));
      expect(auth['After F'], const AuthConfig.bearer(token: 'top'));
    });

    test('an api key from a folder becomes a header on each request below', () {
      final result = parse(collection(items: [
        folder('Keyed', [request('a'), request('b')], auth: {'type': 'apikey', 'apikey': [{'key': 'key', 'value': 'X-Key'}, {'key': 'value', 'value': 'v'}]}),
      ]));

      expect(result.endpoints.map((e) => e.headers.single.key), ['X-Key', 'X-Key']);
    });
  });

  group('the collection\'s variables', () {
    test('become an environment named after the collection, never active', () {
      final result = parse(collection(
        name: 'Petstore',
        variables: [
          {'key': 'base_url', 'value': 'https://x.test'},
          {'key': 'token', 'value': 'abc', 'type': 'secret'},
          {'key': 'n', 'value': 5},
        ],
        items: [request('r')],
      ));

      final env = result.environments.single;
      expect(env.name, 'Petstore (imported)');
      expect(env.variables['base_url']!.value, 'https://x.test');
      expect(env.variables['token']!.secret, isTrue);
      expect(env.variables['token']!.value, 'abc');
      expect(env.variables['n']!.value, '5');
    });

    test('no variables, no environment', () {
      expect(parse(collection(items: [request('r')])).environments, isEmpty);
      expect(parse(collection(variables: [], items: [request('r')])).environments, isEmpty);
    });

    test('names are renamed the way they are in the requests, and reported once for the file', () {
      final result = parse(collection(
        variables: [{'key': 'base-url', 'value': 'https://x.test'}],
        items: [request('r', url: '{{base-url}}/a')],
      ));

      expect(result.environments.single.variables.keys, ['base_url']);
      expect(result.endpoints.single.url, '{{base_url}}/a');
      expect(result.warnings.where((w) => w.message.startsWith('variable names changed')), hasLength(1));
    });

    test('a disabled variable is left out, and named in a warning', () {
      final result = parse(collection(variables: [{'key': 'a', 'value': '1'}, {'key': 'b', 'value': '2', 'disabled': true}], items: [request('r')]));

      expect(result.environments.single.variables.keys, ['a']);
      expect(messages(result), contains('disabled variables were left out: b'));
    });

    test('those of a folder join the same environment, with a warning that names the folder', () {
      final result = parse(collection(
        variables: [{'key': 'a', 'value': '1'}],
        items: [folder('Pets', [request('r')], variables: [{'key': 'pet_id', 'value': '7'}])],
      ));

      expect(result.environments.single.variables.keys, ['a', 'pet_id']);
      expect(result.warnings.any((w) => w.where == 'Pets' && w.message == 'variables defined on this folder were added to the imported environment (they are not scoped to the folder here)'), isTrue);
    });

    test('a folder variable that repeats a name keeps the first value, with a warning', () {
      final result = parse(collection(
        variables: [{'key': 'a', 'value': 'first'}],
        items: [folder('F', [request('r')], variables: [{'key': 'a', 'value': 'second'}])],
      ));

      expect(result.environments.single.variables['a']!.value, 'first');
      expect(messages(result), contains('variable "a" is defined more than once; the first value was kept'));
    });

    test('a collection with variables and no requests still brings the environment', () {
      final result = parse(collection(variables: [{'key': 'a', 'value': '1'}]));

      expect(result.endpoints, isEmpty);
      expect(result.environments, hasLength(1));
      expect(() => runImport(jsonEncode(collection(variables: [{'key': 'a', 'value': '1'}])), importers), returnsNormally);
    });
  });

  group('a v1 collection', () {
    test('is refused with a message that says what to do', () {
      expect(
        () => importer.parse(ImportSource(jsonEncode({'id': 'a', 'name': 'Old', 'order': [], 'folders': [], 'requests': [{'id': 'r'}]}))),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', 'That is a Postman collection v1, which is not supported. Export it again as v2.1.')),
      );
    });
  });

  group('the real registry', () {
    test('picks the collection importer for a collection, the environment one for an environment, the app\'s for its own', () {
      final collectionText = jsonEncode(collection(items: [request('r')]));
      final environmentText = File('test/engine/import/postman/fixtures/staging.postman_environment.json').readAsStringSync();
      final appText = jsonEncode({
        'groups': [{'id': 'g', 'name': 'G'}],
        'endpoints': [{'id': 'e', 'groupId': 'g', 'name': 'n', 'method': 'GET', 'url': '/'}],
      });

      expect(runImport(collectionText, importers).source, 'Postman collection');
      expect(runImport(environmentText, importers).source, 'Postman environment');
      expect(runImport(appText, importers).source, 'API Flow Studio collections');
    });

    test('a collection with nothing at all in it is not imported', () {
      expect(
        () => runImport(jsonEncode(collection()), importers),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', 'Nothing to import: Postman collection had no requests.')),
      );
    });

    test('odd shapes inside a collection are read tolerantly, not rejected', () {
      expect(
        () => runImport(jsonEncode({'info': {'name': 'x'}, 'item': [{'name': 'a', 'request': {'method': 'GET', 'url': 'u'}}], 'variable': 7}), importers),
        returnsNormally,
        reason: 'odd shapes are read tolerantly, not rejected',
      );
    });
  });

  group('a realistic collection', () {
    late ImportResult result;
    setUpAll(() {
      final text = File('test/engine/import/postman/fixtures/petstore.postman_collection.json').readAsStringSync();
      result = runImport(text, importers, fileName: 'petstore.postman_collection.json');
    });

    Endpoint named(String name) => result.endpoints.firstWhere((e) => e.name == name);

    test('has the folders and requests of the file', () {
      expect(result.groups.map((g) => g.name), ['Petstore API', 'Auth', 'Pets', 'Photos', 'Reports']);
      expect(result.endpoints.map((e) => e.name), [
        'Login', 'Refresh', 'List pets', 'Get pet', 'Upload photo', 'Export XML', 'Search', 'Dump', 'Basic report', 'With examples', 'Health',
      ]);
    });

    test('Login: a JSON body with translated variables, and no authentication (its folder says noauth)', () {
      final login = named('Login');

      expect(login.method, 'POST');
      expect(login.url, '{{base_url}}/{{api_version}}/login');
      expect(login.body, const RequestBody.json('{"user": "{{user_name}}", "id": "{{\$uuid}}"}'));
      expect(login.authConfig, const AuthConfig.none());
      expect(login.headers.single, const KeyValueEntry(key: 'Content-Type', value: 'application/json'));
    });

    test('List pets: the params come from the query list, one of them off, plus the folder\'s api key header', () {
      final list = named('List pets');

      expect(list.url, '{{base_url}}/pets');
      expect(list.queryParams, const [
        KeyValueEntry(key: 'limit', value: '10'),
        KeyValueEntry(key: 'sort', value: 'name'),
        KeyValueEntry(key: 'debug', value: 'true', enabled: false),
      ]);
      expect(list.headers.map((h) => h.key), ['Accept', 'X-Api-Key']);
      expect(list.headers.last.value, '{{client_secret}}');
      expect(list.authConfig, const AuthConfig.none());
    });

    test('Get pet: the path variable is filled in', () {
      expect(named('Get pet').url, '{{base_url}}/pets/7');
    });

    test('Upload photo: a text field, a file to choose, and a disabled file; with no path anywhere', () {
      final fields = named('Upload photo').body.maybeMap(multipart: (b) => b.fields, orElse: () => throw StateError('not multipart'));

      expect(fields, const [
        MultipartField(name: 'caption', value: 'A pet'),
        MultipartField(name: 'photo', kind: MultipartFieldKind.file),
        MultipartField(name: 'thumb', kind: MultipartFieldKind.file, enabled: false),
      ]);
      expect(jsonEncode([for (final e in result.endpoints) e.toJson()]), isNot(contains('/Users/someone')));
      expect(named('Upload photo').headers.map((h) => h.key), ['X-Api-Key'], reason: 'it inherits the Pets folder api key, not the collection bearer');
    });

    test('Reports: an unsupported auth type, once, and its requests have none; one request has its own basic', () {
      expect(named('Export XML').authConfig, const AuthConfig.none());
      expect(named('Basic report').authConfig, const AuthConfig.basic(username: 'ana', password: '{{report_password}}'));
      expect(result.warnings.where((w) => w.message.startsWith('auth type "oauth2"')).map((w) => w.where), ['Reports']);
    });

    test('bodies of the other kinds', () {
      expect(named('Export XML').headers.single, const KeyValueEntry(key: 'Content-Type', value: 'application/xml'));
      expect(jsonDecode(named('Search').body.maybeMap(json: (b) => b.raw, orElse: () => '{}'))['variables'], {'limit': 5});
      expect(named('Dump').body, const RequestBody.none());
    });

    test('Health: inherits the collection\'s bearer token, with the variable renamed', () {
      expect(named('Health').authConfig, const AuthConfig.bearer(token: '{{access_token}}'));
    });

    test('the collection variables and the folder\'s are one environment', () {
      final env = result.environments.single;

      expect(env.name, 'Petstore API (imported)');
      expect(env.variables.keys, ['base_url', 'api_version', 'client_secret', 'pet_id']);
      expect(env.variables['client_secret']!.secret, isTrue);
      expect(env.variables['base_url']!.value, 'https://petstore.test');
    });

    test('everything left out or changed is in the warnings, each located', () {
      final byPlace = {for (final w in result.warnings) '${w.where}|${w.message}'};

      expect(byPlace, containsAll([
        'Collection|pre-request script ignored',
        '|disabled variables were left out: old',
        'Pets|variables defined on this folder were added to the imported environment (they are not scoped to the folder here)',
        'Pets / Get pet|test script ignored',
        'Pets / Photos / Upload photo|file field "photo" needs a file chosen',
        'Reports|auth type "oauth2" is not supported; requests that inherit it have no authentication',
        'Reports / Export XML|raw body in "xml" imported as text with Content-Type application/xml',
        'Reports / Dump|binary (file) body is not supported; the body was left empty',
        'Empty|it has neither a request nor items; skipped',
        '|2 saved example responses were not imported',
        'Login|{{user_name}} is not defined by this file; when the request is sent it takes the value of a variable of yours with that name, if there is one',
      ]));
      expect(result.warnings.where((w) => w.message.startsWith('variable names changed')), hasLength(1));
      // 11 left out or changed, and 4 variables the file uses but does not define.
      expect(result.warnings, hasLength(15));
    });
  });
}
