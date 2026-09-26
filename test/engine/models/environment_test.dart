import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Environment', () {
    test('round-trips through JSON with equality preserved', () {
      const env = Environment(
        id: 'env-1',
        name: 'Development',
        variables: {
          'base_url': EnvironmentVariable(value: 'https://api.dev.example.com'),
          'api_key': EnvironmentVariable(value: 'shh', secret: true),
        },
      );

      expect(Environment.fromJson(env.toJson()), env);
    });

    test('resolvedVariables flattens to plain key-value map regardless of secret flag', () {
      const env = Environment(
        id: 'env-1',
        name: 'Development',
        variables: {
          'base_url': EnvironmentVariable(value: 'https://api.dev.example.com'),
          'api_key': EnvironmentVariable(value: 'shh', secret: true),
        },
      );

      expect(env.resolvedVariables, {
        'base_url': 'https://api.dev.example.com',
        'api_key': 'shh',
      });
    });
  });
}
