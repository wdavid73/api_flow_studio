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
  });
}
