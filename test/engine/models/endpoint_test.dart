import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Endpoint', () {
    test('defaults body to none and authConfig to none', () {
      const endpoint = Endpoint(
        id: 'e-1',
        groupId: 'g-1',
        name: 'Login',
        method: 'POST',
        url: '{{base_url}}/auth/login',
      );

      expect(endpoint.body, const RequestBody.none());
      expect(endpoint.authConfig, const AuthConfig.none());
      expect(endpoint.headers, isEmpty);
      expect(endpoint.queryParams, isEmpty);
    });

    test('round-trips a fully populated endpoint through JSON', () {
      const endpoint = Endpoint(
        id: 'e-1',
        groupId: 'g-1',
        name: 'Login',
        method: 'POST',
        url: '{{base_url}}/auth/login',
        headers: [KeyValueEntry(key: 'Content-Type', value: 'application/json')],
        queryParams: [KeyValueEntry(key: 'debug', value: 'true', enabled: false)],
        body: RequestBody.json('{"email":"{{user_email}}"}'),
        authConfig: AuthConfig.bearer(token: '{{auth_token}}'),
      );

      expect(Endpoint.fromJson(endpoint.toJson()), endpoint);
    });
  });
}
