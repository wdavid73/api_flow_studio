import 'package:api_flow_studio/engine/import/import_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImportSource.json', () {
    test('is the decoded JSON of the text', () {
      expect(ImportSource('{"a": [1, 2]}').json, {'a': [1, 2]});
      expect(ImportSource('[1, 2]').json, [1, 2]);
      expect(ImportSource('"text"').json, 'text');
    });

    test('is null for text that is not JSON, and does not throw', () {
      expect(ImportSource('openapi: 3.0.0').json, isNull);
      expect(ImportSource('{"a":').json, isNull);
      expect(ImportSource('').json, isNull);
    });

    test('is the same object every time: it is decoded once', () {
      final source = ImportSource('{"a": 1}');

      expect(identical(source.json, source.json), isTrue);
    });

    test('keeps the file name it was given', () {
      expect(ImportSource('{}', fileName: 'api.json').fileName, 'api.json');
      expect(ImportSource('{}').fileName, isNull);
    });
  });
}
