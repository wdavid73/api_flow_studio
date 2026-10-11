import 'dart:convert';
import 'dart:io';

import 'package:api_flow_studio/engine/import/import_registry.dart';
import 'package:api_flow_studio/engine/import/import_result.dart';
import 'package:api_flow_studio/engine/import/importer.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whole files, through the real registry.
void main() {
  String fixture(String name) => File('test/engine/import/openapi/fixtures/$name').readAsStringSync();

  Iterable<String> messages(ImportResult r) => r.warnings.map((w) => w.message);
  Set<String> located(ImportResult r) => {for (final w in r.warnings) '${w.where}|${w.message}'};

  group('the registry', () {
    test('picks the OpenAPI importer for a JSON file and for a YAML file', () {
      expect(runImport(fixture('petstore.openapi.json'), importers, fileName: 'petstore.openapi.json').source, 'OpenAPI 3.0 spec');
      expect(runImport(fixture('orders.openapi.yaml'), importers, fileName: 'orders.openapi.yaml').source, 'OpenAPI 3.1 spec');
    });

    test('still picks the right one for the other formats', () {
      final postman = jsonEncode({'info': {'name': 'P'}, 'item': [{'name': 'r', 'request': {'method': 'GET', 'url': 'https://x.test'}}]});
      final app = jsonEncode({
        'groups': [{'id': 'g', 'name': 'G'}],
        'endpoints': [{'id': 'e', 'groupId': 'g', 'name': 'n', 'method': 'GET', 'url': '/'}],
      });

      expect(runImport(postman, importers).source, 'Postman collection');
      expect(runImport(app, importers).source, 'API Flow Studio collections');
    });

    test('offers json, yaml and yml to the open dialog, and lists the format among the supported ones', () {
      expect(supportedExtensions(importers), ['json', 'yaml', 'yml']);
      expect(
        () => runImport('{"hello": 1}', importers),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', contains('OpenAPI spec'))),
      );
    });

    test('a Swagger 2.0 file and a broken YAML are explained, not imported', () {
      expect(
        () => runImport('{"swagger": "2.0", "info": {}}', importers),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', contains('Swagger 2.0'))),
      );
      expect(
        () => runImport('openapi: 3.0.0\ninfo: [unclosed\n', importers),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', startsWith('That file is not valid YAML'))),
      );
    });

    test('a spec with no paths still brings its environment', () {
      final result = runImport(jsonEncode({'openapi': '3.0.0', 'info': {'title': 'Empty'}, 'servers': [{'url': 'https://x.test'}]}), importers);

      expect(result.endpoints, isEmpty);
      expect(result.environments.single.variables['base_url']!.value, 'https://x.test');
    });
  });

  group('the Petstore (3.0, JSON)', () {
    late ImportResult result;
    setUpAll(() => result = runImport(fixture('petstore.openapi.json'), importers));

    Endpoint named(String name) => result.endpoints.firstWhere((e) => e.name == name);

    test('has a folder per tag in the order of the file, and a request per operation', () {
      expect(result.groups.map((g) => g.name), ['Petstore', 'pets', 'owners', 'store']);
      expect(result.endpoints.map((e) => e.name), [
        'List pets', 'Add a pet', 'Get a pet', 'Delete a pet', 'Upload a photo', 'List owners', 'Place an order', 'Export a report', 'Legacy',
      ]);
      final groupOf = {for (final g in result.groups) g.id: g.name};
      expect({for (final e in result.endpoints) e.name: groupOf[e.groupId]}, {
        'List pets': 'pets',
        'Add a pet': 'pets',
        'Get a pet': 'pets',
        'Delete a pet': 'pets',
        'Upload a photo': 'pets',
        'List owners': 'owners',
        'Place an order': 'store',
        'Export a report': 'Petstore',
        'Legacy': 'Petstore',
      });
    });

    test('the environment has the server filled in, then variables, then the credentials', () {
      final env = result.environments.single;

      expect(env.name, 'Petstore (imported)');
      expect(env.variables.keys, ['base_url', 'petId', 'X_Request_Id', 'BearerAuth_token']);
      expect(env.variables['base_url']!.value, 'https://api.petstore.test/v2');
      expect(env.variables['petId']!.value, '7');
      expect(env.variables['BearerAuth_token']!.secret, isTrue);
      expect(env.variables['BearerAuth_token']!.value, '');
    });

    test('List pets: the parameters of the file, required on and optional off, with the global bearer', () {
      final list = named('List pets');

      expect(list.url, '{{base_url}}/pets');
      expect(list.queryParams, const [
        KeyValueEntry(key: 'limit', value: '20', enabled: false),
        KeyValueEntry(key: 'status', value: 'available'),
        KeyValueEntry(key: 'tags', value: 'a', enabled: false),
        KeyValueEntry(key: 'tags', value: 'b', enabled: false),
      ]);
      expect(list.authConfig, const AuthConfig.bearer(token: '{{BearerAuth_token}}'));
    });

    test('Add a pet: a sample JSON without the read-only id, the recursive part left out, and no authentication (OAuth)', () {
      final add = named('Add a pet');

      expect(jsonDecode(add.body.maybeMap(json: (b) => b.raw, orElse: () => '')), {
        'name': 'Rex',
        'category': {'name': 'string'},
        'photoUrls': ['https://example.com'],
        'extra': null,
      });
      expect(add.authConfig, const AuthConfig.none());
      expect(add.headers, isEmpty, reason: 'JSON was preferred over XML, so no Content-Type is added');
    });

    test('Get a pet and Delete a pet: the path parameter, the global bearer, and security [] meaning none', () {
      expect(named('Get a pet').url, '{{base_url}}/pets/{{petId}}');
      expect(named('Get a pet').authConfig, const AuthConfig.bearer(token: '{{BearerAuth_token}}'));
      expect(named('Delete a pet').authConfig, const AuthConfig.none());
    });

    test('Upload a photo: a file still to choose with its content type, and a caption that is off', () {
      final fields = named('Upload a photo').body.maybeMap(multipart: (b) => b.fields, orElse: () => throw StateError('not multipart'));

      expect(fields, const [
        MultipartField(name: 'file', kind: MultipartFieldKind.file, contentType: 'image/png'),
        MultipartField(name: 'caption', value: 'A pet', enabled: false),
      ]);
    });

    test('List owners: a required header with nothing to go on is a variable', () {
      expect(named('List owners').headers, const [KeyValueEntry(key: 'X-Request-Id', value: '{{X_Request_Id}}')]);
    });

    test('Place an order: a form', () {
      expect(named('Place an order').body, const RequestBody.formUrlEncoded([
        KeyValueEntry(key: 'petId', value: '7'),
        KeyValueEntry(key: 'quantity', value: '', enabled: false),
      ]));
    });

    test('Export a report: XML text with its Content-Type', () {
      final report = named('Export a report');

      expect(report.body, const RequestBody.json('<report/>'));
      expect(report.headers, const [KeyValueEntry(key: 'Content-Type', value: 'application/xml')]);
    });

    test('everything left out or changed is in the warnings, each located', () {
      expect(located(result), {
        '|other servers were not imported: https://sandbox.petstore.test/v2',
        'components.securitySchemes.OAuth|security scheme "OAuth" (oauth2) is not supported; requests that use it have no authentication',
        'POST /pets|external reference "https://example.com/schemas/extra.json#/Extra" was not followed',
        '|schema "#/components/schemas/Category" refers to itself; the recursive part was left out of the examples',
        'POST /pets/{petId}/photo|file field "file" needs a file chosen',
        'GET /legacy|cookie parameter "session" was not imported',
        'POST /reports|request body in "application/xml" imported as text with Content-Type application/xml',
        '|webhooks and callbacks were not imported',
        '|variable names changed (only letters, digits and _ are supported): X-Request-Id → X_Request_Id',
      });
      expect(result.warnings, hasLength(9));
    });

    test('nothing in the result is a file path', () {
      expect(jsonEncode([for (final e in result.endpoints) e.toJson()]), isNot(contains('/Users')));
    });
  });

  group('the Orders API (3.1, YAML)', () {
    late ImportResult result;
    setUpAll(() => result = runImport(fixture('orders.openapi.yaml'), importers));

    Endpoint named(String name) => result.endpoints.firstWhere((e) => e.name == name);

    test('has the folders and requests of the file, with operationId and method+path as names', () {
      expect(result.groups.map((g) => g.name), ['Orders API', 'orders', 'customers']);
      expect(result.endpoints.map((e) => e.name), [
        'listOrders', 'Create an order', 'Get an order', 'Cancel an order', 'List customers', 'PUT /customers/{id}/avatar',
      ]);
    });

    test('the shared parameter (an alias) is read in both operations, and a 3.1 type list gives its enum', () {
      expect(named('listOrders').queryParams, const [
        KeyValueEntry(key: 'limit', value: '25', enabled: false),
        KeyValueEntry(key: 'status', value: 'open'),
      ]);
      expect(named('List customers').queryParams, const [KeyValueEntry(key: 'limit', value: '25', enabled: false)]);
    });

    test('Create an order: allOf merged, the example kept, the first alternative of oneOf, the cycle cut', () {
      final create = named('Create an order');

      expect(jsonDecode(create.body.maybeMap(json: (b) => b.raw, orElse: () => '')), {
        'customer': {
          'name': 'string',
          'address': {'street': 'string', 'city': 'string'},
        },
        'note': 'leave at the door',
        'items': [
          {'sku': 'string', 'qty': 1},
        ],
      });
      expect(create.authConfig, const AuthConfig.bearer(token: '{{bearer_token}}'));
    });

    test('security: none by default, none when it is []', () {
      expect(named('Get an order').authConfig, const AuthConfig.none());
      expect(named('Cancel an order').authConfig, const AuthConfig.none());
      expect(named('Get an order').url, '{{base_url}}/orders/{{orderId}}');
    });

    test('the avatar is a file still to choose', () {
      final fields = named('PUT /customers/{id}/avatar').body.maybeMap(multipart: (b) => b.fields, orElse: () => throw StateError('not multipart'));

      expect(fields, const [
        MultipartField(name: 'avatar', kind: MultipartFieldKind.file),
        MultipartField(name: 'note', enabled: false),
      ]);
    });

    test('the environment has an empty base_url (no servers) and the bearer token to fill in', () {
      final env = result.environments.single;

      expect(env.name, 'Orders API (imported)');
      expect(env.variables.keys, ['base_url', 'orderId', 'id', 'bearer_token']);
      expect(env.variables['base_url']!.value, '');
      expect(env.variables['bearer_token']!.secret, isTrue);
    });

    test('the warnings', () {
      expect(located(result), {
        '|the file declares no servers; set base_url in the imported environment',
        '|schema "#/components/schemas/Customer" refers to itself; the recursive part was left out of the examples',
        'PUT /customers/{id}/avatar|file field "avatar" needs a file chosen',
        '|webhooks and callbacks were not imported',
      });
    });
  });

  group('webhooks and callbacks', () {
    Map<String, Object?> spec({Map<String, Object?>? webhooks, Map<String, Object?>? callbacks}) => {
          'openapi': '3.0.0',
          'info': {'title': 'T'},
          'servers': [{'url': 'https://x.test'}],
          'webhooks': ?webhooks,
          'paths': {
            '/a': {
              'post': {'summary': 'a', 'callbacks': ?callbacks},
            },
          },
        };

    test('callbacks of an operation are reported once, even with no webhooks', () {
      final result = runImport(jsonEncode(spec(callbacks: {'onEvent': {'{\$request.body#/url}': {'post': {}}}})), importers);

      expect(messages(result).where((m) => m == 'webhooks and callbacks were not imported'), hasLength(1));
    });

    test('a file with neither says nothing about them', () {
      final result = runImport(jsonEncode(spec()), importers);

      expect(messages(result).where((m) => m.contains('webhooks')), isEmpty);
    });

    test('empty webhooks and callbacks are not worth a warning', () {
      final result = runImport(jsonEncode(spec(webhooks: {}, callbacks: {})), importers);

      expect(messages(result).where((m) => m.contains('webhooks')), isEmpty);
    });
  });

  group('references that go outside the file', () {
    test('are never read: a path, a file URL and a web URL are only warned about', () {
      final result = runImport(jsonEncode({
        'openapi': '3.0.0',
        'info': {'title': 'T'},
        'servers': [{'url': 'https://x.test'}],
        'paths': {
          '/a': {
            'post': {
              'requestBody': {
                'content': {
                  'application/json': {
                    'schema': {
                      'type': 'object',
                      'properties': {
                        'a': {r'$ref': 'pubspec.yaml#/name'},
                        'b': {r'$ref': 'file:///etc/passwd'},
                        'c': {r'$ref': 'http://127.0.0.1:1/never'},
                      },
                    },
                  },
                },
              },
            },
          },
        },
      }), importers);

      expect(messages(result).where((m) => m.startsWith('external reference')), hasLength(3));
      expect(jsonDecode(result.endpoints.single.body.maybeMap(json: (b) => b.raw, orElse: () => '')), {'a': null, 'b': null, 'c': null});
    });
  });

  group('a hostile file', () {
    test('with schemas that share the same nodes a million times over is cut, quickly, with a warning', () {
      final lines = <String>[
        'openapi: 3.0.0',
        'info: {title: bomb}',
        'servers: [{url: "https://x.test"}]',
        'components:',
        '  schemas:',
        '    s0: &s0 {type: string}',
      ];
      for (var i = 1; i <= 9; i++) {
        final children = List.generate(10, (p) => 'p$p: *s${i - 1}').join(', ');
        lines.add('    s$i: &s$i {type: object, properties: {$children}}');
      }
      lines.addAll([
        'paths:',
        '  /bomb:',
        '    post:',
        '      summary: Bomb',
        '      requestBody:',
        '        content:',
        '          application/json:',
        '            schema: *s9',
      ]);
      final watch = Stopwatch()..start();

      final result = runImport(lines.join('\n'), importers);

      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
      expect(result.endpoints.single.name, 'Bomb');
      expect(messages(result), contains('the example was cut short (it is too deep or too large)'));
    });

    test('with a chain of references that never ends is cut', () {
      final schemas = <String, Object?>{
        for (var i = 0; i < 60; i++) 'S$i': {r'$ref': '#/components/schemas/S${i + 1}'},
      };
      final result = runImport(jsonEncode({
        'openapi': '3.0.0',
        'info': {'title': 'T'},
        'servers': [{'url': 'https://x.test'}],
        'paths': {
          '/a': {
            'post': {
              'requestBody': {'content': {'application/json': {'schema': {r'$ref': '#/components/schemas/S0'}}}},
            },
          },
        },
        'components': {'schemas': schemas},
      }), importers);

      expect(result.endpoints, hasLength(1));
      expect(messages(result), contains('reference "#/components/schemas/S0" is nested too deeply'));
    });
  });
}
