import 'package:api_flow_studio/engine/models/environment_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isProductionEnvironment', () {
    test('recognises prod, production and prd', () {
      for (final name in ['prod', 'production', 'prd']) {
        expect(isProductionEnvironment(name), isTrue, reason: name);
      }
    });

    test('ignores case and surrounding whitespace', () {
      expect(isProductionEnvironment('  PROD '), isTrue);
      expect(isProductionEnvironment('Production'), isTrue);
    });

    test('is false for anything else, including names that merely contain it', () {
      for (final name in ['dev', 'qa', 'staging', 'preprod', 'prod-eu', '', 'products']) {
        expect(isProductionEnvironment(name), isFalse, reason: name);
      }
    });
  });
}
