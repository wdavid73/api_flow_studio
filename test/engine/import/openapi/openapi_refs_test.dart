import 'package:api_flow_studio/engine/import/import_result.dart';
import 'package:api_flow_studio/engine/import/openapi/openapi_refs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<ImportWarning> warnings;

  OpenApiRefs refsFor(Map<String, dynamic> document) => OpenApiRefs(document, warnings);

  setUp(() => warnings = []);

  Map<String, dynamic> doc() => {
        'components': {
          'schemas': {
            'Pet': {'type': 'object', 'x': 'pet'},
            'Alias': {r'$ref': '#/components/schemas/Pet'},
            'Alias2': {r'$ref': '#/components/schemas/Alias'},
            'Loop1': {r'$ref': '#/components/schemas/Loop2'},
            'Loop2': {r'$ref': '#/components/schemas/Loop1'},
            'Self': {r'$ref': '#/components/schemas/Self'},
            'List': {
              'oneOf': [
                {'x': 'first'},
                {'x': 'second'},
              ],
            },
          },
        },
        'paths': {
          '/pets/{id}': {'get': {'x': 'get pet'}},
          'a~b': {'x': 'tilde'},
          'a~1b': {'x': 'literal tilde-one'},
          'with space': {'x': 'spaced'},
        },
        'x-root': 'root',
      };

  group('resolve', () {
    test('a value that is not a reference is returned as it is', () {
      final refs = refsFor(doc());

      expect(refs.resolve({'type': 'string'}), {'type': 'string'});
      expect(warnings, isEmpty);
    });

    test('nothing and non-objects stay nothing', () {
      final refs = refsFor(doc());

      expect(refs.resolve(null), isNull);
      expect(refs.resolve('text'), isNull);
      expect(refs.resolve([1, 2]), isNull);
    });

    test('a local reference gives its target', () {
      expect(refsFor(doc()).resolve({r'$ref': '#/components/schemas/Pet'}), {'type': 'object', 'x': 'pet'});
      expect(warnings, isEmpty);
    });

    test('a reference to a reference is followed to the end', () {
      expect(refsFor(doc()).resolve({r'$ref': '#/components/schemas/Alias2'})!['x'], 'pet');
    });

    test('siblings of the \$ref are ignored: the target is what counts', () {
      final target = refsFor(doc()).resolve({r'$ref': '#/components/schemas/Pet', 'description': 'ignored'});

      expect(target!['x'], 'pet');
      expect(target.containsKey('description'), isFalse);
    });

    test('a \$ref that is not text is just a property', () {
      expect(refsFor(doc()).resolve({r'$ref': 5, 'a': 1}), {r'$ref': 5, 'a': 1});
    });

    test('~1 is a slash and ~0 a tilde in a pointer, and %-escapes are decoded', () {
      final refs = refsFor(doc());

      expect(refs.resolve({r'$ref': '#/paths/~1pets~1{id}/get'})!['x'], 'get pet');
      expect(refs.resolve({r'$ref': '#/paths/a~0b'})!['x'], 'tilde');
      // ~01 is a tilde followed by a 1 (the key `a~1b`), not a slash: ~1 is decoded first.
      expect(refs.resolve({r'$ref': '#/paths/a~01b'})!['x'], 'literal tilde-one');
      expect(refs.resolve({r'$ref': '#/paths/with%20space'})!['x'], 'spaced');
      expect(warnings, isEmpty);
    });

    test('a list is walked by index', () {
      expect(refsFor(doc()).resolve({r'$ref': '#/components/schemas/List/oneOf/1'})!['x'], 'second');
    });

    test('# alone is the whole document', () {
      expect(refsFor(doc()).resolve({r'$ref': '#'})!['x-root'], 'root');
    });

    test('keys that are numbers in YAML can be reached', () {
      final refs = refsFor({
        'responses': {200: {'description': 'ok'}},
      });

      expect(refs.resolve({r'$ref': '#/responses/200'})!['description'], 'ok');
    });
  });

  group('what cannot be resolved', () {
    test('a reference to nowhere gives nothing and one warning, however often it is asked', () {
      final refs = refsFor(doc());
      final missing = {r'$ref': '#/components/schemas/Nope'};

      expect(refs.resolve(missing, where: 'GET /pets'), isNull);
      expect(refs.resolve(missing, where: 'GET /owners'), isNull);

      expect(warnings, hasLength(1));
      expect(warnings.single.where, 'GET /pets');
      expect(warnings.single.message, 'reference "#/components/schemas/Nope" was not found');
    });

    test('a pointer into something that is not an object or list is not found', () {
      expect(refsFor(doc()).resolve({r'$ref': '#/x-root/deeper'}), isNull);
      expect(refsFor(doc()).resolve({r'$ref': '#/components/schemas/List/oneOf/9'}), isNull);
      expect(refsFor(doc()).resolve({r'$ref': '#/components/schemas/List/oneOf/abc'}), isNull);
    });

    test('references that point at each other give nothing and a warning', () {
      final refs = refsFor(doc());

      expect(refs.resolve({r'$ref': '#/components/schemas/Loop1'}, where: 'POST /x'), isNull);
      expect(warnings.single.message, 'reference "#/components/schemas/Loop1" is circular');
      expect(warnings.single.where, 'POST /x');
    });

    test('a reference to itself is circular too', () {
      expect(refsFor(doc()).resolve({r'$ref': '#/components/schemas/Self'}), isNull);
      expect(warnings.single.message, contains('is circular'));
    });

    test('a very long chain is cut', () {
      final chain = <String, dynamic>{'end': {'x': 'end'}};
      for (var i = 0; i < 40; i++) {
        chain['r$i'] = {r'$ref': '#/${i == 39 ? 'end' : 'r${i + 1}'}'};
      }

      expect(refsFor(chain).resolve({r'$ref': '#/r0'}), isNull);
      expect(warnings.single.message, 'reference "#/r0" is nested too deeply');
    });

    group('external references', () {
      test('a file is not followed, not read: it is one warning and nothing', () {
        final refs = refsFor(doc());

        expect(refs.resolve({r'$ref': 'pubspec.yaml#/name'}), isNull);
        expect(refs.resolve({r'$ref': './schemas/pet.yaml'}), isNull);
        expect(warnings.map((w) => w.message), [
          'external reference "pubspec.yaml#/name" was not followed',
          'external reference "./schemas/pet.yaml" was not followed',
        ]);
      });

      test('a URL is not followed either', () {
        expect(refsFor(doc()).resolve({r'$ref': 'https://example.com/pet.json#/Pet'}), isNull);
        expect(warnings.single.message, 'external reference "https://example.com/pet.json#/Pet" was not followed');
      });

      test('the same one is warned once', () {
        final refs = refsFor(doc());

        refs.resolve({r'$ref': 'other.yaml#/A'});
        refs.resolve({r'$ref': 'other.yaml#/A'});

        expect(warnings, hasLength(1));
      });
    });
  });
}
