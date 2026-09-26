import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthConfig', () {
    test('none round-trips through JSON', () {
      const auth = AuthConfig.none();

      expect(AuthConfig.fromJson(auth.toJson()), auth);
    });

    test('basic round-trips username and password', () {
      const auth = AuthConfig.basic(username: 'alice', password: 'secret');

      expect(AuthConfig.fromJson(auth.toJson()), auth);
    });

    test('bearer round-trips its token', () {
      const auth = AuthConfig.bearer(token: 'abc123');

      expect(AuthConfig.fromJson(auth.toJson()), auth);
    });
  });
}
