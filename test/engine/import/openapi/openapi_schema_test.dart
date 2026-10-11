import 'package:api_flow_studio/engine/import/import_result.dart';
import 'package:api_flow_studio/engine/import/openapi/openapi_refs.dart';
import 'package:api_flow_studio/engine/import/openapi/openapi_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<ImportWarning> warnings;
  late SchemaSampler sampler;

  void useDocument([Map<String, dynamic> document = const {}]) {
    warnings = [];
    sampler = SchemaSampler(OpenApiRefs(document, warnings), warnings);
  }

  Object? sample(Object? schema, {String where = 'POST /x'}) => sampler.sample(schema, where: where);

  setUp(useDocument);

  group('a value the file gives', () {
    test('example comes first, then default, const, and the first enum value', () {
      expect(sample({'type': 'string', 'example': 'given', 'default': 'd'}), 'given');
      expect(sample({'type': 'string', 'default': 'd', 'enum': ['e']}), 'd');
      expect(sample({'type': 'string', 'const': 'c', 'enum': ['e']}), 'c');
      expect(sample({'type': 'string', 'enum': ['red', 'green']}), 'red');
    });

    test('an example may be any JSON value, nested', () {
      expect(sample({'example': {'id': 1, 'tags': ['a', 'b'], 'ok': true, 'none': null}}), {'id': 1, 'tags': ['a', 'b'], 'ok': true, 'none': null});
    });

    test('an example with keys that are numbers (YAML) becomes plain JSON data', () {
      expect(sample({'example': {200: 'ok', 'x': {404: 'missing'}}}), {'200': 'ok', 'x': {'404': 'missing'}});
    });

    test('an example of null is null, not "nothing given"', () {
      expect(sample({'type': 'string', 'example': null, 'default': 'd'}), isNull);
    });
  });

  group('scalars', () {
    test('strings by format', () {
      expect(sample({'type': 'string'}), 'string');
      expect(sample({'type': 'string', 'format': 'date-time'}), '2024-01-01T00:00:00Z');
      expect(sample({'type': 'string', 'format': 'date'}), '2024-01-01');
      expect(sample({'type': 'string', 'format': 'email'}), 'user@example.com');
      expect(sample({'type': 'string', 'format': 'uuid'}), '00000000-0000-0000-0000-000000000000');
      expect(sample({'type': 'string', 'format': 'uri'}), 'https://example.com');
      expect(sample({'type': 'string', 'format': 'something-else'}), 'string');
    });

    test('numbers are zero, or their minimum', () {
      expect(sample({'type': 'integer'}), 0);
      expect(sample({'type': 'number'}), 0);
      expect(sample({'type': 'integer', 'minimum': 5}), 5);
      expect(sample({'type': 'number', 'minimum': -3}), -3);
    });

    test('booleans are true and null is null', () {
      expect(sample({'type': 'boolean'}), true);
      expect(sample({'type': 'null'}), isNull);
    });

    test('a type given as a list (3.1) uses the first one that is not null', () {
      expect(sample({'type': ['null', 'string']}), 'string');
      expect(sample({'type': ['integer', 'null']}), 0);
      expect(sample({'type': ['null']}), isNull);
    });

    test('with no type it is guessed from the shape, and nothing to go on is null', () {
      expect(sample({'properties': {'a': {'type': 'string'}}}), {'a': 'string'});
      expect(sample({'items': {'type': 'integer'}}), [0]);
      expect(sample(<String, Object?>{}), isNull);
      expect(sample(null), isNull);
      expect(sample('not a schema'), isNull);
    });
  });

  group('objects and arrays', () {
    test('an object has each of its properties, except the read-only ones', () {
      final value = sample({
        'type': 'object',
        'properties': {
          'id': {'type': 'integer', 'readOnly': true},
          'name': {'type': 'string'},
          'password': {'type': 'string', 'writeOnly': true},
          'tags': {'type': 'array', 'items': {'type': 'string'}},
        },
      });

      expect(value, {'name': 'string', 'password': 'string', 'tags': ['string']});
    });

    test('an object with no properties is empty', () {
      expect(sample({'type': 'object'}), <String, Object?>{});
    });

    test('an array has one element, and none when it does not say what is in it', () {
      expect(sample({'type': 'array', 'items': {'type': 'integer'}}), [0]);
      expect(sample({'type': 'array'}), <Object?>[]);
    });

    test('nested structures are filled in', () {
      expect(sample({
        'type': 'object',
        'properties': {
          'owner': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
              'pets': {'type': 'array', 'items': {'type': 'object', 'properties': {'age': {'type': 'integer'}}}},
            },
          },
        },
      }), {
        'owner': {'name': 'string', 'pets': [{'age': 0}]},
      });
    });
  });

  group('compositions', () {
    test('allOf merges the properties of every part', () {
      expect(sample({
        'allOf': [
          {'type': 'object', 'properties': {'id': {'type': 'integer'}}},
          {'type': 'object', 'properties': {'name': {'type': 'string'}}},
          {'properties': {'tag': {'type': 'string'}}},
        ],
      }), {'id': 0, 'name': 'string', 'tag': 'string'});
    });

    test('allOf with properties of its own adds them too', () {
      expect(sample({
        'type': 'object',
        'properties': {'own': {'type': 'boolean'}},
        'allOf': [
          {'type': 'object', 'properties': {'id': {'type': 'integer'}}},
        ],
      }), {'own': true, 'id': 0});
    });

    test('oneOf and anyOf take the first alternative', () {
      expect(sample({'oneOf': [{'type': 'string'}, {'type': 'integer'}]}), 'string');
      expect(sample({'anyOf': [{'type': 'integer'}, {'type': 'string'}]}), 0);
    });
  });

  group('references', () {
    test('a \$ref is followed, including inside properties and items', () {
      useDocument({
        'components': {
          'schemas': {
            'Pet': {'type': 'object', 'properties': {'name': {'type': 'string'}}},
            'Owner': {'type': 'object', 'properties': {'pets': {'type': 'array', 'items': {r'$ref': '#/components/schemas/Pet'}}}},
          },
        },
      });

      expect(sample({r'$ref': '#/components/schemas/Owner'}), {
        'pets': [{'name': 'string'}],
      });
      expect(warnings, isEmpty);
    });

    test('a reference that cannot be resolved is nothing, with its own warning', () {
      expect(sample({'type': 'object', 'properties': {'x': {r'$ref': '#/nowhere'}, 'y': {'type': 'string'}}}), {'x': null, 'y': 'string'});
      expect(warnings.single.message, 'reference "#/nowhere" was not found');
    });

    test('a schema that refers to itself leaves the recursive part out, with one warning', () {
      useDocument({
        'components': {
          'schemas': {
            'Category': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'parent': {r'$ref': '#/components/schemas/Category'},
                'children': {'type': 'array', 'items': {r'$ref': '#/components/schemas/Category'}},
              },
            },
          },
        },
      });

      expect(sample({r'$ref': '#/components/schemas/Category'}, where: 'POST /categories'), {'name': 'string'});
      expect(sample({r'$ref': '#/components/schemas/Category'}, where: 'PUT /categories'), {'name': 'string'});

      expect(warnings, hasLength(1), reason: 'once per schema, not once per operation');
      expect(warnings.single.message, 'schema "#/components/schemas/Category" refers to itself; the recursive part was left out of the examples');
    });
  });

  group('limits', () {
    test('a very deep structure is cut at 8 levels, with a warning', () {
      Map<String, dynamic> level(int n) => n == 0
          ? {'type': 'string'}
          : {'type': 'object', 'properties': {'next': level(n - 1)}};

      final value = sample(level(30), where: 'POST /deep');

      // Objects at depth 0..8 are filled in; what would be at depth 9 is left out (null).
      var objects = 0;
      Object? cursor = value;
      while (cursor is Map && cursor.containsKey('next')) {
        cursor = cursor['next'];
        objects++;
      }
      expect(objects, SchemaSampler.maxDepth + 1);
      expect(cursor, isNull);
      expect(warnings.single.where, 'POST /deep');
      expect(warnings.single.message, 'the example was cut short (it is too deep or too large)');
    });

    test('a very wide, shared structure is cut at 2000 nodes, quickly', () {
      // Each level has 10 properties that all share the same child: 10^6 nodes if expanded.
      Map<String, dynamic> shared = {'type': 'string'};
      for (var i = 0; i < 6; i++) {
        final child = shared;
        shared = {'type': 'object', 'properties': {for (var p = 0; p < 10; p++) 'p$p': child}};
      }
      final watch = Stopwatch()..start();

      final value = sample(shared);

      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(_countNodes(value), lessThanOrEqualTo(2100));
      expect(warnings, hasLength(1));
    });

    test('an example that is itself huge or shared is cut too', () {
      Object shared = ['x'];
      for (var i = 0; i < 8; i++) {
        final child = shared;
        shared = List.filled(10, child);
      }
      final watch = Stopwatch()..start();

      final value = sample({'example': shared});

      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(_countNodes(value), lessThanOrEqualTo(2100));
      expect(warnings.single.message, 'the example was cut short (it is too deep or too large)');
    });

    test('each sample starts with a fresh allowance', () {
      Map<String, dynamic> shared = {'type': 'string'};
      for (var i = 0; i < 6; i++) {
        final child = shared;
        shared = {'type': 'object', 'properties': {for (var p = 0; p < 10; p++) 'p$p': child}};
      }
      sample(shared);

      expect(sample({'type': 'string'}), 'string');
      expect(warnings, hasLength(1));
    });
  });
}

int _countNodes(Object? value) {
  if (value is Map) return 1 + value.values.fold(0, (sum, v) => sum + _countNodes(v));
  if (value is List) return 1 + value.fold(0, (sum, v) => sum + _countNodes(v));
  return 1;
}
