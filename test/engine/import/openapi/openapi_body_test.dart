import 'dart:convert';

import 'package:api_flow_studio/engine/import/import_result.dart';
import 'package:api_flow_studio/engine/import/import_source.dart';
import 'package:api_flow_studio/engine/import/openapi/openapi_importer.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const importer = OpenApiImporter();

  ImportResult parse(Object? requestBody, {Map<String, Object?>? components}) => importer.parse(ImportSource(jsonEncode({
        'openapi': '3.0.3',
        'info': {'title': 'T', 'version': '1'},
        'servers': [{'url': 'https://x.test'}],
        'paths': {
          '/things': {
            'post': {
              'responses': {'200': {'description': 'ok'}},
              'requestBody': ?requestBody,
            },
          },
        },
        'components': ?components,
      })));

  Endpoint endpointOf(Object? requestBody, {Map<String, Object?>? components}) => parse(requestBody, components: components).endpoints.single;

  Map<String, Object?> content(Map<String, Object?> byType) => {'content': byType};

  const petSchema = {
    'type': 'object',
    'required': ['name'],
    'properties': {
      'id': {'type': 'integer', 'readOnly': true},
      'name': {'type': 'string'},
      'tag': {'type': 'string', 'enum': ['dog', 'cat']},
    },
  };

  String jsonOf(Endpoint e) => e.body.maybeMap(json: (b) => b.raw, orElse: () => throw StateError('body is ${e.body}'));
  List<KeyValueEntry> formOf(Endpoint e) => e.body.maybeMap(formUrlEncoded: (b) => b.fields, orElse: () => throw StateError('body is ${e.body}'));
  List<MultipartField> multipartOf(Endpoint e) => e.body.maybeMap(multipart: (b) => b.fields, orElse: () => throw StateError('body is ${e.body}'));
  Iterable<String> messages(ImportResult r) => r.warnings.map((w) => w.message);

  group('no body', () {
    test('an operation without a requestBody has none', () {
      expect(endpointOf(null).body, const RequestBody.none());
    });

    test('a requestBody with no content, or content that is not a map, has none', () {
      expect(endpointOf({'description': 'x'}).body, const RequestBody.none());
      expect(endpointOf({'content': 'nope'}).body, const RequestBody.none());
      expect(endpointOf({'content': <String, Object?>{}}).body, const RequestBody.none());
    });

    test('a requestBody given as a reference is followed', () {
      final endpoint = endpointOf(
        {r'$ref': '#/components/requestBodies/NewPet'},
        components: {
          'requestBodies': {
            'NewPet': content({'application/json': {'example': {'name': 'Rex'}}}),
          },
        },
      );

      expect(jsonDecode(jsonOf(endpoint)), {'name': 'Rex'});
    });
  });

  group('JSON', () {
    test('uses the example of the media type, indented', () {
      final endpoint = endpointOf(content({'application/json': {'schema': petSchema, 'example': {'name': 'Rex', 'tag': 'dog'}}}));

      expect(jsonOf(endpoint), '{\n  "name": "Rex",\n  "tag": "dog"\n}');
      expect(endpoint.headers, isEmpty);
    });

    test('else the first of its examples', () {
      final endpoint = endpointOf(content({
        'application/json': {
          'examples': {
            'first': {'summary': 'A dog', 'value': {'name': 'Rex'}},
            'second': {'value': {'name': 'Tom'}},
          },
        },
      }));

      expect(jsonDecode(jsonOf(endpoint)), {'name': 'Rex'});
    });

    test('else a sample of the schema, without the read-only properties', () {
      final endpoint = endpointOf(content({'application/json': {'schema': petSchema}}));

      expect(jsonDecode(jsonOf(endpoint)), {'name': 'string', 'tag': 'dog'});
    });

    test('a schema given as a reference is followed', () {
      final endpoint = endpointOf(
        content({'application/json': {'schema': {r'$ref': '#/components/schemas/Pet'}}}),
        components: {'schemas': {'Pet': petSchema}},
      );

      expect(jsonDecode(jsonOf(endpoint)), {'name': 'string', 'tag': 'dog'});
    });

    test('an example that is a list or a scalar is kept as it is', () {
      expect(jsonDecode(jsonOf(endpointOf(content({'application/json': {'example': [1, 2]}})))), [1, 2]);
      expect(jsonDecode(jsonOf(endpointOf(content({'application/json': {'example': 'text'}})))), 'text');
    });

    test('with parameters in the media type name it is still JSON and adds no header', () {
      final endpoint = endpointOf(content({'application/json; charset=utf-8': {'example': {'a': 1}}}));

      expect(jsonDecode(jsonOf(endpoint)), {'a': 1});
      expect(endpoint.headers, isEmpty);
    });

    test('another JSON type adds its own Content-Type', () {
      final endpoint = endpointOf(content({'application/vnd.api+json': {'example': {'data': {}}}}));

      expect(jsonDecode(jsonOf(endpoint)), {'data': <String, Object?>{}});
      expect(endpoint.headers, const [KeyValueEntry(key: 'Content-Type', value: 'application/vnd.api+json')]);
    });

    test('with no schema and no example there is nothing to send', () {
      expect(endpointOf(content({'application/json': <String, Object?>{}})).body, const RequestBody.none());
    });

    test('a broken reference in the schema is warned about and the rest is kept', () {
      final result = parse(content({
        'application/json': {
          'schema': {
            'type': 'object',
            'properties': {
              'a': {r'$ref': '#/components/schemas/Nope'},
              'b': {'type': 'string'},
            },
          },
        },
      }));

      expect(jsonDecode(jsonOf(result.endpoints.single)), {'a': null, 'b': 'string'});
      expect(messages(result), contains('reference "#/components/schemas/Nope" was not found'));
    });
  });

  group('which type is chosen', () {
    test('JSON beats everything else', () {
      final endpoint = endpointOf(content({
        'application/xml': {'example': '<a/>'},
        'application/x-www-form-urlencoded': {'schema': petSchema},
        'application/json': {'example': {'a': 1}},
      }));

      expect(jsonDecode(jsonOf(endpoint)), {'a': 1});
      expect(endpoint.headers, isEmpty);
    });

    test('a +json type beats a form, a form beats multipart, multipart beats text', () {
      expect(jsonOf(endpointOf(content({'application/x-www-form-urlencoded': {'schema': petSchema}, 'application/ld+json': {'example': {'a': 1}}}))), contains('"a"'));
      expect(formOf(endpointOf(content({'multipart/form-data': {'schema': petSchema}, 'application/x-www-form-urlencoded': {'schema': petSchema}}))), isNotEmpty);
      expect(multipartOf(endpointOf(content({'text/plain': {'example': 'x'}, 'multipart/form-data': {'schema': petSchema}}))), isNotEmpty);
    });

    test('the alternatives left out are not a warning: they are other ways to say the same thing', () {
      final result = parse(content({
        'application/json': {'example': {'a': 1}},
        'application/xml': {'example': '<a/>'},
      }));

      expect(result.warnings, isEmpty);
    });
  });

  group('url-encoded form', () {
    test('required properties are on with their value, optional ones off', () {
      final endpoint = endpointOf(content({
        'application/x-www-form-urlencoded': {
          'schema': {
            'type': 'object',
            'required': ['grant_type', 'username'],
            'properties': {
              'grant_type': {'type': 'string', 'enum': ['password']},
              'username': {'type': 'string'},
              'scope': {'type': 'string', 'example': 'read'},
              'remember': {'type': 'boolean'},
            },
          },
        },
      }));

      expect(formOf(endpoint), const [
        KeyValueEntry(key: 'grant_type', value: 'password'),
        KeyValueEntry(key: 'username', value: '{{username}}'),
        KeyValueEntry(key: 'scope', value: 'read', enabled: false),
        KeyValueEntry(key: 'remember', value: '', enabled: false),
      ]);
    });

    test('a required property with nothing to go on is a variable the environment has, empty', () {
      final result = parse(content({
        'application/x-www-form-urlencoded': {
          'schema': {'type': 'object', 'required': ['token'], 'properties': {'token': {'type': 'string'}}},
        },
      }));

      expect(result.environments.single.variables['token']!.value, '');
    });

    test('a read-only property is not something to send', () {
      final form = endpointOf(content({
        'application/x-www-form-urlencoded': {
          'schema': {'type': 'object', 'properties': {'id': {'type': 'integer', 'readOnly': true}, 'name': {'type': 'string'}}},
        },
      }));
      final multipart = endpointOf(content({
        'multipart/form-data': {
          'schema': {'type': 'object', 'properties': {'id': {'type': 'integer', 'readOnly': true}, 'name': {'type': 'string'}}},
        },
      }));

      expect(formOf(form).map((f) => f.key), ['name']);
      expect(multipartOf(multipart).map((f) => f.name), ['name']);
    });

    test('the properties of allOf parts are all there', () {
      final endpoint = endpointOf(content({
        'application/x-www-form-urlencoded': {
          'schema': {
            'allOf': [
              {'type': 'object', 'properties': {'a': {'type': 'string', 'example': '1'}}, 'required': ['a']},
              {'type': 'object', 'properties': {'b': {'type': 'string', 'example': '2'}}},
            ],
          },
        },
      }));

      expect(formOf(endpoint).map((f) => '${f.key}:${f.enabled}'), ['a:true', 'b:false']);
    });

    test('an array property is one row per element', () {
      final endpoint = endpointOf(content({
        'application/x-www-form-urlencoded': {
          'schema': {'type': 'object', 'required': ['ids'], 'properties': {'ids': {'type': 'array', 'items': {'type': 'integer'}, 'example': [1, 2]}}},
        },
      }));

      expect(formOf(endpoint).map((f) => f.value), ['1', '2']);
    });

    test('an object-valued property is written as JSON text', () {
      final endpoint = endpointOf(content({
        'application/x-www-form-urlencoded': {
          'schema': {'type': 'object', 'required': ['meta'], 'properties': {'meta': {'type': 'object', 'example': {'a': 1}}}},
        },
      }));

      expect(formOf(endpoint).single.value, '{"a":1}');
    });
  });

  group('multipart form', () {
    Map<String, Object?> upload({Map<String, Object?>? encoding, List<String> required = const ['file']}) => content({
          'multipart/form-data': {
            'schema': {
              'type': 'object',
              'required': required,
              'properties': {
                'file': {'type': 'string', 'format': 'binary'},
                'caption': {'type': 'string', 'example': 'A pet'},
                'extra': {'type': 'string', 'contentMediaType': 'application/pdf'},
                'many': {'type': 'array', 'items': {'type': 'string', 'format': 'binary'}},
                'meta': {'type': 'object', 'example': {'k': 'v'}},
              },
            },
            'encoding': ?encoding,
          },
        });

    test('binary properties are files still to choose; the rest is text', () {
      final fields = multipartOf(endpointOf(upload()));

      expect(fields, const [
        MultipartField(name: 'file', kind: MultipartFieldKind.file),
        MultipartField(name: 'caption', value: 'A pet', enabled: false),
        MultipartField(name: 'extra', kind: MultipartFieldKind.file, enabled: false),
        MultipartField(name: 'many', kind: MultipartFieldKind.file, enabled: false),
        MultipartField(name: 'meta', value: '{"k":"v"}', enabled: false),
      ]);
    });

    test('the content type of a file comes from the encoding, the first when it lists several', () {
      final fields = multipartOf(endpointOf(upload(encoding: {
        'file': {'contentType': 'image/png, image/jpeg'},
        'extra': {'contentType': 'application/pdf'},
      })));

      expect(fields.firstWhere((f) => f.name == 'file').contentType, 'image/png');
      expect(fields.firstWhere((f) => f.name == 'extra').contentType, 'application/pdf');
    });

    test('an enabled file is warned about, a disabled one is not', () {
      final required = parse(upload());
      final optional = parse(upload(required: const []));

      expect(messages(required), contains('file field "file" needs a file chosen'));
      expect(required.warnings.every((w) => w.where == 'POST /things'), isTrue);
      expect(messages(optional).where((m) => m.contains('needs a file chosen')), isEmpty);
    });

    test('required text properties are on', () {
      final fields = multipartOf(endpointOf(upload(required: const ['file', 'caption'])));

      expect(fields.firstWhere((f) => f.name == 'caption').enabled, isTrue);
    });

    test('no path can come from a file property', () {
      final fields = multipartOf(endpointOf(upload()));

      expect(fields.where((f) => f.kind == MultipartFieldKind.file).every((f) => f.value.isEmpty), isTrue);
    });
  });

  group('text and XML', () {
    test('an example is the body, with its Content-Type, and a warning', () {
      final result = parse(content({'application/xml': {'example': '<pet><name>Rex</name></pet>'}}));
      final endpoint = result.endpoints.single;

      expect(jsonOf(endpoint), '<pet><name>Rex</name></pet>');
      expect(endpoint.headers, const [KeyValueEntry(key: 'Content-Type', value: 'application/xml')]);
      expect(result.warnings.single.where, 'POST /things');
      expect(result.warnings.single.message, 'request body in "application/xml" imported as text with Content-Type application/xml');
    });

    test('plain text and +xml types work the same', () {
      final plain = endpointOf(content({'text/plain': {'example': 'hello'}}));
      final soap = endpointOf(content({'application/soap+xml': {'example': '<a/>'}}));

      expect(plain.headers.single.value, 'text/plain');
      expect(soap.headers.single.value, 'application/soap+xml');
    });

    test('the example can be one of examples, or in the schema', () {
      expect(jsonOf(endpointOf(content({'text/plain': {'examples': {'a': {'value': 'from examples'}}}}))), 'from examples');
      expect(jsonOf(endpointOf(content({'text/plain': {'schema': {'type': 'string', 'example': 'from schema'}}}))), 'from schema');
    });

    test('with no example the body is empty, and the warning says so', () {
      final result = parse(content({'application/xml': {'schema': petSchema}}));

      expect(result.endpoints.single.body, const RequestBody.none());
      expect(result.endpoints.single.headers, isEmpty);
      expect(messages(result), ['the "application/xml" body has no example; left empty']);
    });
  });

  group('binary only', () {
    test('has no body, with a warning', () {
      for (final type in ['application/octet-stream', 'image/png', 'application/pdf']) {
        final result = parse(content({type: {'schema': {'type': 'string', 'format': 'binary'}}}));

        expect(result.endpoints.single.body, const RequestBody.none(), reason: type);
        expect(messages(result), ['binary request body is not supported; the body was left empty'], reason: type);
      }
    });

    test('a binary type next to a usable one is not a problem', () {
      final result = parse(content({
        'application/octet-stream': {'schema': {'type': 'string', 'format': 'binary'}},
        'application/json': {'example': {'a': 1}},
      }));

      expect(jsonDecode(jsonOf(result.endpoints.single)), {'a': 1});
      expect(result.warnings, isEmpty);
    });
  });
}
