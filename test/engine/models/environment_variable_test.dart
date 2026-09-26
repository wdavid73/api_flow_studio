import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnvironmentVariable', () {
    test('defaults secret to false', () {
      const variable = EnvironmentVariable(value: 'https://api.dev.example.com');

      expect(variable.secret, isFalse);
    });

    test('round-trips through JSON with equality preserved', () {
      const variable = EnvironmentVariable(value: 'topsecret', secret: true);

      expect(EnvironmentVariable.fromJson(variable.toJson()), variable);
    });
  });
}
