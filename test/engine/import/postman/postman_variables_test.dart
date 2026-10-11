import 'package:api_flow_studio/engine/import/postman/postman_json.dart';
import 'package:api_flow_studio/engine/import/postman/postman_variables.dart';
import 'package:api_flow_studio/engine/variables/dynamic_values.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VariableTranslator.translate', () {
    late VariableTranslator translator;
    setUp(() => translator = VariableTranslator());

    test('leaves a text without variables alone', () {
      expect(translator.translate('https://api.test/users'), 'https://api.test/users');
      expect(translator.translate(''), '');
    });

    test('leaves a well-formed variable alone', () {
      expect(translator.translate('{{base_url}}/users/{{id}}'), '{{base_url}}/users/{{id}}');
      expect(translator.renamed, isEmpty);
    });

    test('trims spaces inside the braces', () {
      expect(translator.translate('{{ base_url }}'), '{{base_url}}');
      expect(translator.translate('{{  id}}'), '{{id}}');
    });

    test('leaves JSON braces and single braces alone', () {
      const json = '{"a": {"b": 1}, "c": [{"d": 2}]}';

      expect(translator.translate(json), json);
      expect(translator.translate('{x} {{ }} {{}}'), '{x} {{ }} {{}}');
    });

    test('works inside a JSON body next to nested braces', () {
      expect(translator.translate('{"user": {"id": "{{user-id}}"}}'), '{"user": {"id": "{{user_id}}"}}');
    });

    group('names the engine cannot resolve', () {
      test('are renamed with underscores and remembered', () {
        expect(translator.translate('{{base-url}}/{{api.version}}/{{my var}}'), '{{base_url}}/{{api_version}}/{{my_var}}');
        expect(translator.renamed, {'base-url': 'base_url', 'api.version': 'api_version', 'my var': 'my_var'});
      });

      test('are renamed the same way every time', () {
        expect(translator.translate('{{a-b}}'), translator.translate('x{{a-b}}').substring(1));
        expect(translator.renamed, {'a-b': 'a_b'});
      });

      test('a name made only of symbols becomes underscores', () {
        expect(translator.translate('{{-}}'), '{{_}}');
      });

      test('sanitizeName renames an environment key the same way', () {
        expect(translator.sanitizeName('base-url'), 'base_url');
        expect(translator.sanitizeName('ok_name'), 'ok_name');
        expect(translator.renamed, {'base-url': 'base_url'});
      });
    });

    group('dynamic variables', () {
      test('Postman names become this app\'s names', () {
        expect(translator.translate('{{\$guid}}'), '{{\$uuid}}');
        expect(translator.translate('{{\$randomUUID}}'), '{{\$uuid}}');
        expect(translator.translate('{{\$randomAlphaNumeric}}'), '{{\$randomString}}');
      });

      test('the ones that already match are kept', () {
        for (final name in ['timestamp', 'isoTimestamp', 'randomInt', 'randomEmail']) {
          expect(translator.translate('{{\$$name}}'), '{{\$$name}}', reason: name);
        }
      });

      test('every result is something the engine can generate', () {
        for (final postman in ['guid', 'randomUUID', 'timestamp', 'isoTimestamp', 'randomInt', 'randomEmail', 'randomAlphaNumeric']) {
          final translated = translator.translate('{{\$$postman}}');
          final name = translated.substring(3, translated.length - 2);
          expect(DynamicValues.isKnown(name), isTrue, reason: '$postman -> $translated');
        }
      });

      test('spaces are ignored', () {
        expect(translator.translate('{{ \$guid }}'), '{{\$uuid}}');
      });

      test('an unknown one is left as written and reported to the caller', () {
        final unknown = <String>[];

        final text = translator.translate('{{\$randomFirstName}} {{\$guid}} {{\$randomFirstName}}', unknownDynamic: unknown);

        expect(text, '{{\$randomFirstName}} {{\$uuid}} {{\$randomFirstName}}');
        expect(unknown, ['randomFirstName']);
        expect(translator.renamed, isEmpty);
      });
    });
  });

  group('renamedWarning', () {
    test('is null when nothing was renamed', () {
      expect(VariableTranslator().renamedWarning(), isNull);
    });

    test('lists every change once, for the whole file', () {
      final translator = VariableTranslator()..translate('{{a-b}} {{a-b}} {{c.d}}');

      final warning = translator.renamedWarning()!;

      expect(warning.where, '');
      expect(warning.message, 'variable names changed (only letters, digits and _ are supported): a-b → a_b, c.d → c_d');
    });
  });

  group('tolerant readers', () {
    test('asMap, asList and asString ignore the wrong type instead of throwing', () {
      expect(asMap({'a': 1}), {'a': 1});
      expect(asMap([1]), isNull);
      expect(asMap('x'), isNull);
      expect(asList([1, 2]), [1, 2]);
      expect(asList({'a': 1}), isEmpty);
      expect(asList(null), isEmpty);
      expect(asString('x'), 'x');
      expect(asString(3), isNull);
      expect(asString(null), isNull);
    });

    test('textOf reads a description given as text or as an object', () {
      expect(textOf('plain'), 'plain');
      expect(textOf({'content': 'in an object', 'type': 'text/plain'}), 'in an object');
      expect(textOf({'type': 'text/plain'}), '');
      expect(textOf(null), '');
      expect(textOf(42), '');
    });
  });
}
