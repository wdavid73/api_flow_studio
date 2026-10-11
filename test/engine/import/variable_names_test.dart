import 'package:api_flow_studio/engine/import/variable_names.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late VariableNames names;
  setUp(() => names = VariableNames());

  group('sanitize', () {
    test('keeps a name made of letters, digits and underscores', () {
      expect(names.sanitize('base_url'), 'base_url');
      expect(names.sanitize('Pet2'), 'Pet2');
      expect(names.renamed, isEmpty);
    });

    test('replaces everything else with underscores, and remembers the change', () {
      expect(names.sanitize('base-url'), 'base_url');
      expect(names.sanitize('api.key'), 'api_key');
      expect(names.sanitize('my var'), 'my_var');
      expect(names.renamed, {'base-url': 'base_url', 'api.key': 'api_key', 'my var': 'my_var'});
    });

    test('is the same every time', () {
      expect(names.sanitize('a-b'), names.sanitize('a-b'));
      expect(names.renamed, {'a-b': 'a_b'});
    });

    test('a name of only symbols becomes underscores', () {
      expect(names.sanitize('-'), '_');
    });
  });

  group('renamedWarning', () {
    test('is null when nothing was renamed', () {
      expect(names.renamedWarning(), isNull);
    });

    test('lists every change once, for the whole file', () {
      names
        ..sanitize('a-b')
        ..sanitize('a-b')
        ..sanitize('c.d');

      final warning = names.renamedWarning()!;

      expect(warning.where, '');
      expect(warning.message, 'variable names changed (only letters, digits and _ are supported): a-b → a_b, c.d → c_d');
    });
  });
}
