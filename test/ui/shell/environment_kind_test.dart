import 'package:api_flow_studio/ui/shell/environment_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isProductionEnvironment', () {
    for (final name in ['prod', 'PROD', ' Production ', 'prd', 'Prd']) {
      test('"$name" is production', () {
        expect(isProductionEnvironment(name), isTrue);
      });
    }

    for (final name in ['staging', 'preprod', 'product', 'QA', '']) {
      test('"$name" is not production', () {
        expect(isProductionEnvironment(name), isFalse);
      });
    }
  });
}
