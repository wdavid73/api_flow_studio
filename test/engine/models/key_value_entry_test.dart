import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KeyValueEntry', () {
    test('defaults enabled to true', () {
      const entry = KeyValueEntry(key: 'Content-Type', value: 'application/json');

      expect(entry.enabled, isTrue);
    });

    test('round-trips through JSON with equality preserved', () {
      const entry = KeyValueEntry(key: 'X-Test', value: '123', enabled: false);

      final json = entry.toJson();
      final decoded = KeyValueEntry.fromJson(json);

      expect(decoded, entry);
    });
  });
}
