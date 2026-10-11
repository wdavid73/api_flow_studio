import 'package:api_flow_studio/engine/import/import_naming.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('uniqueName', () {
    test('is the name itself when nothing has it', () {
      expect(uniqueName('Petstore', ['Other', 'Users']), 'Petstore');
      expect(uniqueName('Petstore', const []), 'Petstore');
    });

    test('numbers a name that is taken', () {
      expect(uniqueName('Petstore', ['Petstore']), 'Petstore (2)');
    });

    test('goes on until it is free', () {
      expect(uniqueName('Petstore', ['Petstore', 'Petstore (2)', 'Petstore (3)']), 'Petstore (4)');
    });

    test('does not mind the case', () {
      expect(uniqueName('Petstore', ['PETSTORE']), 'Petstore (2)');
      expect(uniqueName('petstore', ['Petstore', 'PETSTORE (2)']), 'petstore (3)');
    });

    test('ignores surrounding spaces when comparing', () {
      expect(uniqueName('Petstore', ['  Petstore ']), 'Petstore (2)');
    });

    test('cuts the base to make room for the number when there is a limit', () {
      final name = uniqueName('a' * 10, ['a' * 10], maxLength: 10);

      expect(name, '${'a' * 6} (2)');
      expect(name.length, 10);
    });

    test('a name already within the limit is not cut', () {
      expect(uniqueName('abc', const [], maxLength: 3), 'abc');
    });
  });
}
