import 'dart:convert';

import 'package:api_flow_studio/engine/import/import_result.dart';
import 'package:api_flow_studio/engine/import/import_source.dart';
import 'package:api_flow_studio/engine/import/openapi/openapi_importer.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The structure of the result (folders, order, names, servers) and what the parameters
/// of an operation become, through the importer itself.
void main() {
  const importer = OpenApiImporter();

  Map<String, Object?> spec({
    String? title = 'Pets API',
    Object? servers = const [
      {'url': 'https://pets.test/v1'},
    ],
    Map<String, Object?> paths = const {},
    List<Object?>? tags,
    Map<String, Object?>? components,
  }) =>
      {
        'openapi': '3.0.3',
        'info': {'title': ?title, 'version': '1.0.0'},
        'servers': ?servers,
        'paths': paths,
        'tags': ?tags,
        'components': ?components,
      };

  ImportResult parse(Map<String, Object?> document) => importer.parse(ImportSource(jsonEncode(document)));

  Map<String, Object?> op({String? summary, String? operationId, String? description, List<String>? tags, List<Object?>? parameters, Map<String, Object?> extra = const {}}) => {
        'summary': ?summary,
        'operationId': ?operationId,
        'description': ?description,
        'tags': ?tags,
        'parameters': ?parameters,
        'responses': {'200': {'description': 'ok'}},
        ...extra,
      };

  Endpoint only(ImportResult r) => r.endpoints.single;
  Endpoint one(Map<String, Object?> operation, {String path = '/pets', String method = 'get', List<Object?>? pathParameters, Map<String, Object?>? components}) => only(parse(spec(
        paths: {path: {method: operation, 'parameters': ?pathParameters}},
        components: components,
      )));

  Map<String, Object?> param(String name, String where, {bool required = false, Object? schema = const {'type': 'string'}, Map<String, Object?> extra = const {}}) =>
      {'name': name, 'in': where, 'required': required, 'schema': schema, ...extra};

  Iterable<String> messages(ImportResult r) => r.warnings.map((w) => w.message);

  group('the folders', () {
    test('the API is a root folder named after its title, or a default', () {
      expect(parse(spec(paths: {'/a': {'get': op()}})).groups.single.name, 'Pets API');
      expect(parse(spec(title: null, paths: {'/a': {'get': op()}})).groups.single.name, 'OpenAPI spec');
      expect(parse(spec(title: '  ', paths: {'/a': {'get': op()}})).groups.single.name, 'OpenAPI spec');
    });

    test('an operation lives under its first tag, in tag folders ordered as the file declares them', () {
      final result = parse(spec(
        tags: [
          {'name': 'pets'},
          {'name': 'owners'},
        ],
        paths: {
          '/owners': {'get': op(summary: 'List owners', tags: ['owners'])},
          '/pets': {'get': op(summary: 'List pets', tags: ['pets', 'owners'])},
        },
      ));

      expect(result.groups.map((g) => g.name), ['Pets API', 'pets', 'owners']);
      final byName = {for (final e in result.endpoints) e.name: e};
      final pets = result.groups.firstWhere((g) => g.name == 'pets');
      final owners = result.groups.firstWhere((g) => g.name == 'owners');
      expect(byName['List pets']!.groupId, pets.id);
      expect(byName['List owners']!.groupId, owners.id);
      expect(pets.parentGroupId, result.groups.first.id);
    });

    test('tags the file never declares come after, in order of appearance; unused declared tags make no folder', () {
      final result = parse(spec(
        tags: [
          {'name': 'declared'},
          {'name': 'unused'},
        ],
        paths: {
          '/a': {'get': op(tags: ['late'])},
          '/b': {'get': op(tags: ['declared'])},
        },
      ));

      expect(result.groups.map((g) => g.name), ['Pets API', 'declared', 'late']);
    });

    test('an operation with no tags is in the root folder', () {
      final result = parse(spec(paths: {'/a': {'get': op()}}));

      expect(result.endpoints.single.groupId, result.groups.first.id);
      expect(result.groups, hasLength(1));
    });

    test('an empty tag list or a tag that is not text is no tag', () {
      final result = parse(spec(paths: {
        '/a': {'get': op(tags: [])},
        '/b': {'get': op(extra: {'tags': [3, null]})},
      }));

      expect(result.groups, hasLength(1));
    });

    test('every request points at a folder of the result, and ids are unique', () {
      final result = parse(spec(paths: {
        '/a': {'get': op(tags: ['x']), 'post': op(tags: ['y']), 'delete': op()},
      }));

      final ids = result.groups.map((g) => g.id).toSet();
      expect(ids, hasLength(result.groups.length));
      expect(result.endpoints.map((e) => e.id).toSet(), hasLength(3));
      expect(result.endpoints.every((e) => ids.contains(e.groupId)), isTrue);
    });
  });

  group('the requests', () {
    test('come in the order of the file: paths first, then the methods as they appear', () {
      final result = parse(spec(paths: {
        '/b': {'post': op(summary: 'b post'), 'get': op(summary: 'b get')},
        '/a': {'get': op(summary: 'a get')},
      }));

      expect(result.endpoints.map((e) => e.name), ['b post', 'b get', 'a get']);
      expect(result.endpoints.map((e) => e.method), ['POST', 'GET', 'GET']);
    });

    test('every HTTP method is read, and what is not a method is not', () {
      final result = parse(spec(paths: {
        '/a': {
          'summary': 'a path summary',
          'description': 'text',
          'servers': [{'url': 'https://other.test'}],
          'x-internal': true,
          'parameters': [],
          'get': op(summary: 'g'),
          'put': op(summary: 'p'),
          'post': op(summary: 'po'),
          'delete': op(summary: 'd'),
          'options': op(summary: 'o'),
          'head': op(summary: 'h'),
          'patch': op(summary: 'pa'),
          'trace': op(summary: 't'),
          'fetch': op(summary: 'nope'),
        },
      }));

      expect(result.endpoints.map((e) => e.method), ['GET', 'PUT', 'POST', 'DELETE', 'OPTIONS', 'HEAD', 'PATCH', 'TRACE']);
    });

    test('the name is the summary, else the operationId, else the method and path', () {
      final result = parse(spec(paths: {
        '/a': {
          'get': op(summary: 'Summary wins', operationId: 'getA'),
          'post': op(operationId: 'createA'),
          'put': op(),
          'patch': op(summary: '  '),
        },
      }));

      expect(result.endpoints.map((e) => e.name), ['Summary wins', 'createA', 'PUT /a', 'PATCH /a']);
    });

    test('the description is the description, else the summary', () {
      final result = parse(spec(paths: {
        '/a': {
          'get': op(summary: 'Short', description: 'Long text'),
          'post': op(summary: 'Only short'),
          'put': op(),
        },
      }));

      expect(result.endpoints.map((e) => e.description), ['Long text', 'Only short', '']);
    });

    test('a path item that is a reference is followed', () {
      final result = parse(spec(
        paths: {'/a': {r'$ref': '#/components/x-pathItems/A'}},
        components: {
          'x-pathItems': {'A': {'get': op(summary: 'From a reference')}},
        },
      ));

      expect(result.endpoints.single.name, 'From a reference');
    });

    test('a spec with no operations has no requests', () {
      expect(parse(spec()).endpoints, isEmpty);
      expect(parse(spec(paths: {'/a': {}})).endpoints, isEmpty);
    });

    test('things that are not what they should be are skipped without failing', () {
      final result = parse(spec(paths: {
        '/a': 'text',
        '/b': {'get': 'not an operation'},
        '/c': {'get': op(summary: 'fine')},
      }));

      expect(result.endpoints.map((e) => e.name), ['fine']);
    });
  });

  group('the url', () {
    test('is base_url followed by the path, with {param} written as {{param}}', () {
      final endpoint = one(op(), path: '/pets/{petId}/photos/{photoId}');

      expect(endpoint.url, '{{base_url}}/pets/{{petId}}/photos/{{photoId}}');
    });

    test('a path with no parameters is just joined', () {
      expect(one(op(), path: '/pets').url, '{{base_url}}/pets');
      expect(one(op(), path: '/').url, '{{base_url}}/');
    });

    test('names that cannot be variables are renamed, once for the file', () {
      final result = parse(spec(paths: {'/p/{pet-id}': {'get': op()}, '/q/{pet-id}': {'get': op()}}));

      expect(result.endpoints.map((e) => e.url), ['{{base_url}}/p/{{pet_id}}', '{{base_url}}/q/{{pet_id}}']);
      final renamed = result.warnings.where((w) => w.message.startsWith('variable names changed'));
      expect(renamed, hasLength(1));
      expect(renamed.single.message, contains('pet-id → pet_id'));
    });
  });

  group('the servers', () {
    Map<String, EnvironmentVariable> variablesOf(ImportResult r) => r.environments.single.variables;

    test('the first one is base_url, with no trailing slash', () {
      expect(variablesOf(parse(spec(servers: [{'url': 'https://pets.test/v1/'}], paths: {'/a': {'get': op()}})))['base_url']!.value, 'https://pets.test/v1');
      expect(variablesOf(parse(spec(paths: {'/a': {'get': op()}})))['base_url']!.value, 'https://pets.test/v1');
    });

    test('the variables of a server are filled with their defaults', () {
      final result = parse(spec(
        servers: [
          {
            'url': 'https://{env}.pets.test:{port}/{basePath}',
            'variables': {
              'env': {'default': 'staging', 'enum': ['staging', 'prod']},
              'port': {'default': 8443},
              'basePath': {'default': 'v2'},
            },
          },
        ],
        paths: {'/a': {'get': op()}},
      ));

      expect(variablesOf(result)['base_url']!.value, 'https://staging.pets.test:8443/v2');
    });

    test('a variable with no default is left as written', () {
      final result = parse(spec(servers: [{'url': 'https://{tenant}.pets.test'}], paths: {'/a': {'get': op()}}));

      expect(variablesOf(result)['base_url']!.value, 'https://{tenant}.pets.test');
    });

    test('a relative url is kept, with a warning', () {
      final result = parse(spec(servers: [{'url': '/api/v1'}], paths: {'/a': {'get': op()}}));

      expect(variablesOf(result)['base_url']!.value, '/api/v1');
      expect(messages(result), contains('server URL is relative; set base_url to the host'));
    });

    test('no servers means an empty base_url, with a warning (also when the list is empty)', () {
      for (final servers in <Object?>[null, <Object?>[]]) {
        final result = parse(spec(servers: servers, paths: {'/a': {'get': op()}}));

        expect(variablesOf(result)['base_url']!.value, '');
        expect(messages(result), contains('the file declares no servers; set base_url in the imported environment'));
      }
    });

    test('the other servers are only listed in a warning', () {
      final result = parse(spec(
        servers: [
          {'url': 'https://prod.test'},
          {'url': 'https://staging.test'},
          {'url': 'http://localhost:8080'},
        ],
        paths: {'/a': {'get': op()}},
      ));

      expect(variablesOf(result)['base_url']!.value, 'https://prod.test');
      expect(messages(result), contains('other servers were not imported: https://staging.test, http://localhost:8080'));
    });
  });

  group('the environment', () {
    test('is named after the API, base_url comes first, and path parameters are variables', () {
      final result = parse(spec(paths: {
        '/pets/{petId}': {
          'get': op(parameters: [param('petId', 'path', required: true, extra: {'example': 7})]),
        },
        '/owners/{ownerId}': {'get': op()},
      }));

      final env = result.environments.single;
      expect(env.name, 'Pets API (imported)');
      expect(env.variables.keys, ['base_url', 'petId', 'ownerId']);
      expect(env.variables['petId']!.value, '7');
      expect(env.variables['ownerId']!.value, '');
      expect(env.variables.values.every((v) => !v.secret), isTrue);
    });

    test('the first appearance of a name decides its value', () {
      final result = parse(spec(paths: {
        '/a/{id}': {'get': op(parameters: [param('id', 'path', required: true, extra: {'example': 1})])},
        '/b/{id}': {'get': op(parameters: [param('id', 'path', required: true, extra: {'example': 2})])},
      }));

      expect(result.environments.single.variables['id']!.value, '1');
    });

    test('even a spec with no operations brings its environment', () {
      expect(parse(spec()).environments.single.variables.keys, ['base_url']);
    });
  });

  group('path parameters', () {
    test('take their example, default or first enum into the environment', () {
      final result = parse(spec(paths: {
        '/a/{x}/{y}/{z}': {
          'get': op(parameters: [
            param('x', 'path', required: true, extra: {'example': 'ex'}),
            param('y', 'path', required: true, schema: {'type': 'string', 'default': 'def'}),
            param('z', 'path', required: true, schema: {'type': 'string', 'enum': ['one', 'two']}),
          ]),
        },
      }));

      final v = result.environments.single.variables;
      expect([v['x']!.value, v['y']!.value, v['z']!.value], ['ex', 'def', 'one']);
    });

    test('a path parameter that is not declared still becomes a variable', () {
      final result = parse(spec(paths: {'/a/{undeclared}': {'get': op()}}));

      expect(result.environments.single.variables.keys, contains('undeclared'));
    });
  });

  group('query parameters', () {
    test('a required one is on, with its example', () {
      final endpoint = one(op(parameters: [param('limit', 'query', required: true, schema: {'type': 'integer'}, extra: {'example': 20})]));

      expect(endpoint.queryParams, const [KeyValueEntry(key: 'limit', value: '20')]);
    });

    test('value comes from example, then examples, then default, then enum', () {
      final endpoint = one(op(parameters: [
        param('a', 'query', required: true, schema: {'type': 'string', 'default': 'd'}, extra: {'example': 'ex'}),
        param('b', 'query', required: true, extra: {'examples': {'first': {'value': 'from-examples'}}}),
        param('c', 'query', required: true, schema: {'type': 'string', 'default': 'dflt'}),
        param('d', 'query', required: true, schema: {'type': 'string', 'enum': ['x', 'y']}),
      ]));

      expect(endpoint.queryParams.map((p) => p.value), ['ex', 'from-examples', 'dflt', 'x']);
    });

    test('a required one with nothing given is the variable {{name}}, which the environment has, empty', () {
      final result = parse(spec(paths: {'/a': {'get': op(parameters: [param('q', 'query', required: true, schema: {'type': 'integer'})])}}));

      expect(result.endpoints.single.queryParams, const [KeyValueEntry(key: 'q', value: '{{q}}')]);
      expect(result.environments.single.variables['q']!.value, '');
    });

    test('an optional one is off, with its example or empty', () {
      final endpoint = one(op(parameters: [
        param('sort', 'query', extra: {'example': 'name'}),
        param('page', 'query', schema: {'type': 'integer'}),
      ]));

      expect(endpoint.queryParams, const [
        KeyValueEntry(key: 'sort', value: 'name', enabled: false),
        KeyValueEntry(key: 'page', value: '', enabled: false),
      ]);
    });

    test('a value that is a number or a boolean is written as text', () {
      final endpoint = one(op(parameters: [
        param('n', 'query', required: true, extra: {'example': 3}),
        param('b', 'query', required: true, schema: {'type': 'boolean', 'default': false}),
      ]));

      expect(endpoint.queryParams.map((p) => p.value), ['3', 'false']);
    });

    test('an array is one row per element by default (explode), or joined when it is not', () {
      final endpoint = one(op(parameters: [
        param('ids', 'query', required: true, schema: {'type': 'array', 'items': {'type': 'integer'}}, extra: {'example': [1, 2, 3]}),
        param('tags', 'query', required: true, schema: {'type': 'array', 'items': {'type': 'string'}}, extra: {'example': ['a', 'b'], 'explode': false}),
        param('pipes', 'query', required: true, schema: {'type': 'array', 'items': {'type': 'string'}}, extra: {'example': ['a', 'b'], 'explode': false, 'style': 'pipeDelimited'}),
        param('spaces', 'query', required: true, schema: {'type': 'array', 'items': {'type': 'string'}}, extra: {'example': ['a', 'b'], 'explode': false, 'style': 'spaceDelimited'}),
      ]));

      expect(endpoint.queryParams.map((p) => '${p.key}=${p.value}'), ['ids=1', 'ids=2', 'ids=3', 'tags=a,b', 'pipes=a|b', 'spaces=a b']);
    });

    test('an optional array is off, one row per element', () {
      final endpoint = one(op(parameters: [
        param('ids', 'query', schema: {'type': 'array', 'items': {'type': 'integer'}}, extra: {'example': [1, 2]}),
      ]));

      expect(endpoint.queryParams.every((p) => !p.enabled), isTrue);
      expect(endpoint.queryParams.map((p) => p.value), ['1', '2']);
    });

    test('an object parameter is not imported, with a warning that names it and the operation', () {
      final result = parse(spec(paths: {
        '/a': {
          'get': op(parameters: [
            param('filter', 'query', schema: {'type': 'object', 'properties': {'a': {'type': 'string'}}}, extra: {'style': 'deepObject'}),
            param('ok', 'query', extra: {'example': 'x'}),
          ]),
        },
      }));

      expect(result.endpoints.single.queryParams.map((p) => p.key), ['ok']);
      expect(result.warnings.any((w) => w.where == 'GET /a' && w.message == 'parameter "filter" is an object and was not imported'), isTrue);
    });
  });

  group('header and cookie parameters', () {
    test('a header is like a query parameter: required on, optional off', () {
      final endpoint = one(op(parameters: [
        param('X-Trace-Id', 'header', required: true, extra: {'example': 'abc'}),
        param('X-Debug', 'header', extra: {'example': '1'}),
      ]));

      expect(endpoint.headers, const [
        KeyValueEntry(key: 'X-Trace-Id', value: 'abc'),
        KeyValueEntry(key: 'X-Debug', value: '1', enabled: false),
      ]);
    });

    test('Accept, Content-Type and Authorization are reserved by OpenAPI and ignored, whatever their case', () {
      final endpoint = one(op(parameters: [
        param('Accept', 'header', required: true, extra: {'example': 'a'}),
        param('content-type', 'header', required: true, extra: {'example': 'b'}),
        param('AUTHORIZATION', 'header', required: true, extra: {'example': 'c'}),
        param('X-Keep', 'header', required: true, extra: {'example': 'd'}),
      ]));

      expect(endpoint.headers.map((h) => h.key), ['X-Keep']);
    });

    test('a cookie parameter is not imported, and is warned about', () {
      final result = parse(spec(paths: {
        '/a': {'get': op(parameters: [param('session', 'cookie', required: true)])},
      }));

      expect(result.endpoints.single.headers, isEmpty);
      expect(result.warnings.any((w) => w.where == 'GET /a' && w.message == 'cookie parameter "session" was not imported'), isTrue);
    });
  });

  group('parameters of a path and of an operation', () {
    test('those of the path apply to every operation', () {
      final result = parse(spec(paths: {
        '/a': {
          'parameters': [param('tenant', 'query', required: true, extra: {'example': 't1'})],
          'get': op(),
          'post': op(parameters: [param('extra', 'query', required: true, extra: {'example': 'e'})]),
        },
      }));

      expect(result.endpoints[0].queryParams.map((p) => p.key), ['tenant']);
      expect(result.endpoints[1].queryParams.map((p) => p.key), ['tenant', 'extra']);
    });

    test('an operation\'s parameter replaces the path\'s with the same name and place', () {
      final result = parse(spec(paths: {
        '/a': {
          'parameters': [param('limit', 'query', required: true, extra: {'example': 10})],
          'get': op(parameters: [param('limit', 'query', required: true, extra: {'example': 99})]),
        },
      }));

      expect(result.endpoints.single.queryParams, const [KeyValueEntry(key: 'limit', value: '99')]);
    });

    test('the same name in another place is another parameter', () {
      final result = parse(spec(paths: {
        '/a': {
          'get': op(parameters: [
            param('id', 'query', required: true, extra: {'example': 'q'}),
            param('id', 'header', required: true, extra: {'example': 'h'}),
          ]),
        },
      }));

      expect(result.endpoints.single.queryParams.single.value, 'q');
      expect(result.endpoints.single.headers.single.value, 'h');
    });

    test('a parameter given as a reference is followed', () {
      final endpoint = one(
        op(parameters: [
          {r'$ref': '#/components/parameters/Limit'},
        ]),
        components: {
          'parameters': {'Limit': param('limit', 'query', required: true, extra: {'example': 25})},
        },
      );

      expect(endpoint.queryParams, const [KeyValueEntry(key: 'limit', value: '25')]);
    });

    test('a parameter reference that goes nowhere is skipped, with the reference warning', () {
      final result = parse(spec(paths: {
        '/a': {'get': op(parameters: [{r'$ref': '#/components/parameters/Missing'}, param('ok', 'query', extra: {'example': 'x'})])},
      }));

      expect(result.endpoints.single.queryParams.map((p) => p.key), ['ok']);
      expect(messages(result), contains('reference "#/components/parameters/Missing" was not found'));
    });

    test('rows that are not parameters are ignored', () {
      final endpoint = one(op(parameters: ['junk', 7, {'in': 'query'}, {'name': 'x'}, param('ok', 'query', extra: {'example': 'v'})]));

      expect(endpoint.queryParams.map((p) => p.key), ['ok']);
    });
  });
}
