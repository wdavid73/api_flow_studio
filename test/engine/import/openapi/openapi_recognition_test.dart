import 'dart:convert';

import 'package:api_flow_studio/engine/import/import_json.dart';
import 'package:api_flow_studio/engine/import/import_source.dart';
import 'package:api_flow_studio/engine/import/importer.dart';
import 'package:api_flow_studio/engine/import/openapi/openapi_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const importer = OpenApiImporter();

  bool matchesText(String text) => importer.matches(ImportSource(text));
  bool matchesJson(Object json) => matchesText(jsonEncode(json));

  group('matches', () {
    test('a JSON OpenAPI 3.0 and 3.1', () {
      expect(matchesJson({'openapi': '3.0.3', 'info': {}, 'paths': {}}), isTrue);
      expect(matchesJson({'openapi': '3.1.0', 'info': {}}), isTrue);
    });

    test('a JSON Swagger file (so it can be explained)', () {
      expect(matchesJson({'swagger': '2.0', 'info': {}, 'paths': {}}), isTrue);
    });

    test('a YAML OpenAPI, quoted or not', () {
      expect(matchesText('openapi: 3.0.3\ninfo:\n  title: x\n'), isTrue);
      expect(matchesText('openapi: "3.1.0"\ninfo: {}\n'), isTrue);
      expect(matchesText("openapi: '3.0.0'\n"), isTrue);
      expect(matchesText('# a comment\ninfo:\n  title: x\nopenapi: 3.0.1\npaths: {}\n'), isTrue);
      expect(matchesText('openapi:3.0.0\n'), isTrue);
    });

    test('a YAML Swagger file', () {
      expect(matchesText("swagger: '2.0'\ninfo: {}\n"), isTrue);
      expect(matchesText('swagger: 2.0\n'), isTrue);
    });

    test('not an openapi key that is only nested, or only mentioned', () {
      expect(matchesText('info:\n  openapi: 3.0.0\n'), isFalse);
      expect(matchesText('  openapi: 3.0.0\n'), isFalse);
      expect(matchesText('# openapi: 3.0.0\n'), isFalse);
      expect(matchesText('the openapi: 3.0.0 spec is described here\n'), isFalse);
    });

    test('not an OpenAPI version that is not 3', () {
      expect(matchesJson({'openapi': '2.0.0'}), isFalse);
      expect(matchesJson({'openapi': 3}), isFalse);
      expect(matchesText('openapi: 4.0.0\n'), isFalse);
    });

    test('not the other formats, text or nothing', () {
      expect(matchesJson({'info': {'name': 'x'}, 'item': []}), isFalse);
      expect(matchesJson({'name': 'Staging', 'values': []}), isFalse);
      expect(matchesJson({'groups': [], 'endpoints': []}), isFalse);
      expect(matchesJson(['openapi']), isFalse);
      expect(matchesText('hello'), isFalse);
      expect(matchesText(''), isFalse);
    });

    test('is cheap: it never parses a YAML document to decide', () {
      // Not valid YAML at all, but the first column says openapi: 3.
      expect(matchesText('openapi: 3.0.0\n\t\t: [unclosed {'), isTrue);
    });
  });

  group('the extensions the open dialog offers', () {
    test('are json, yaml and yml', () {
      expect(importer.extensions, ['json', 'yaml', 'yml']);
      expect(importer.formatName, 'OpenAPI spec');
    });
  });

  group('loadOpenApiDocument', () {
    Map<String, dynamic> load(String text) => loadOpenApiDocument(ImportSource(text));

    test('reads JSON', () {
      final doc = load('{"openapi": "3.0.3", "info": {"title": "Pets"}, "paths": {}}');

      expect(doc['openapi'], '3.0.3');
      expect((doc['info'] as Map)['title'], 'Pets');
    });

    test('reads YAML, with the types YAML gives', () {
      final doc = load('''
openapi: 3.1.0
info:
  title: Pets
  version: 1.0.0
  description: |
    Line one
    Line two
paths:
  /pets:
    get:
      parameters:
        - name: limit
          in: query
          required: true
          schema: {type: integer, default: 20}
      responses:
        200:
          description: ok
        "404":
          description: missing
''');

      expect(doc['openapi'], '3.1.0');
      expect((doc['info'] as Map)['description'], 'Line one\nLine two\n');
      final get = ((doc['paths'] as Map)['/pets'] as Map)['get'] as Map;
      final parameter = (get['parameters'] as List).single as Map;
      expect(parameter['required'], true);
      expect((parameter['schema'] as Map)['default'], 20);
    });

    test('keys that are numbers or booleans in YAML are text keys', () {
      final doc = load('openapi: 3.0.0\npaths:\n  /a:\n    get:\n      responses:\n        200: {description: ok}\n');

      // Read the way the importer reads: with the tolerant readers.
      final get = asMap(asMap(asMap(doc['paths'])!['/a'])!['get'])!;
      expect(asMap(get['responses'])!.keys.single, '200');
    });

    test('an openapi version written as a number in YAML is still read', () {
      expect(load('openapi: 3.0\ninfo: {title: x}\n')['openapi'], 3.0);
    });

    test('a YAML that is not valid says so', () {
      expect(
        () => load('openapi: 3.0.0\ninfo:\n  title: [unclosed\n'),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', startsWith('That file is not valid YAML'))),
      );
    });

    test('a document that is not a mapping is refused', () {
      expect(
        () => load('openapi: 3.0.0\n- a\n- b\n'),
        throwsA(isA<ImportException>()),
      );
      expect(
        () => loadOpenApiDocument(ImportSource('[1, 2]')),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', 'That file is not an OpenAPI document.')),
      );
    });

    test('Swagger 2.0 is explained, in JSON and in YAML', () {
      for (final text in ['{"swagger": "2.0", "info": {}}', "swagger: '2.0'\ninfo: {}\n"]) {
        expect(
          () => load(text),
          throwsA(isA<ImportException>().having((e) => e.message, 'message', 'That is a Swagger 2.0 file, which is not supported. Convert it to OpenAPI 3 first.')),
        );
      }
    });

    test('a document with nested aliases is loaded at once, not expanded', () {
      final lines = <String>['openapi: 3.0.0', 'info: {title: bomb}', 'x-a0: &a0 [x, x, x, x, x, x, x, x, x, x]'];
      for (var i = 1; i < 12; i++) {
        lines.add('x-a$i: &a$i [${List.filled(10, '*a${i - 1}').join(', ')}]');
      }
      final watch = Stopwatch()..start();

      final doc = load(lines.join('\n'));

      expect(watch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(doc.keys, contains('x-a11'));
    });
  });
}
