import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RequestBody', () {
    test('none round-trips through JSON', () {
      const body = RequestBody.none();

      expect(RequestBody.fromJson(body.toJson()), body);
    });

    test('json round-trips through JSON, preserving raw string', () {
      const body = RequestBody.json('{"a":1}');

      final decoded = RequestBody.fromJson(body.toJson());

      expect(decoded, body);
      expect(decoded.maybeMap(json: (v) => v.raw, orElse: () => null), '{"a":1}');
    });

    test('formUrlEncoded round-trips its field list', () {
      const body = RequestBody.formUrlEncoded([
        KeyValueEntry(key: 'grant_type', value: 'password'),
      ]);

      final decoded = RequestBody.fromJson(body.toJson());

      expect(decoded, body);
    });

    test('multipart round-trips every field, kind and content type', () {
      const body = RequestBody.multipart([
        MultipartField(name: 'title', value: 'Hello'),
        MultipartField(name: 'avatar', kind: MultipartFieldKind.file, value: '/tmp/a.png', contentType: 'image/png'),
        MultipartField(name: 'doc', kind: MultipartFieldKind.file, value: '/tmp/b.pdf', enabled: false),
      ]);

      final decoded = RequestBody.fromJson(body.toJson());

      expect(decoded, body);
    });

    test('a multipart field without kind or enabled reads as an enabled text field', () {
      final body = RequestBody.fromJson({
        'runtimeType': 'multipart',
        'fields': [
          {'name': 'title', 'value': 'Hello'},
        ],
      });

      final field = body.maybeMap(multipart: (b) => b.fields.single, orElse: () => throw StateError('not multipart'));
      expect(field.kind, MultipartFieldKind.text);
      expect(field.enabled, isTrue);
      expect(field.contentType, isNull);
    });

    test('the JSON of a multipart body names its type and writes plain maps', () {
      final json = const RequestBody.multipart([MultipartField(name: 'a', value: 'b')]).toJson();

      expect(json['runtimeType'], 'multipart');
      expect((json['fields'] as List).single, isA<Map<String, dynamic>>());
      expect(((json['fields'] as List).single as Map)['kind'], 'text');
    });
  });
}
