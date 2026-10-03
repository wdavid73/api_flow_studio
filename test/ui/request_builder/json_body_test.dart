import 'package:api_flow_studio/ui/request_builder/json_body.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isValidJsonBody', () {
    test('an empty body is valid (nothing to complain about yet)', () {
      expect(isValidJsonBody(''), isTrue);
      expect(isValidJsonBody('   \n'), isTrue);
    });

    test('well-formed JSON is valid', () {
      expect(isValidJsonBody('{"a":1,"b":[true,null]}'), isTrue);
      expect(isValidJsonBody('[1,2,3]'), isTrue);
    });

    test('broken JSON is invalid', () {
      expect(isValidJsonBody('{"a":'), isFalse);
      expect(isValidJsonBody("{'a':1}"), isFalse);
      expect(isValidJsonBody('{"a":1,}'), isFalse);
    });

    test('a {{variable}} inside a string is valid', () {
      expect(isValidJsonBody('{"token":"{{token}}"}'), isTrue);
    });

    test('an unquoted {{variable}} as a value is tolerated', () {
      expect(isValidJsonBody('{"id":{{id}}}'), isTrue);
    });
  });

  group('formatJsonBody', () {
    test('pretty-prints valid JSON with two-space indentation', () {
      expect(
        formatJsonBody('{"a":1,"b":[1,2]}'),
        '{\n  "a": 1,\n  "b": [\n    1,\n    2\n  ]\n}',
      );
    });

    test('keeps {{variables}} inside strings', () {
      expect(formatJsonBody('{"t":"{{token}}"}'), '{\n  "t": "{{token}}"\n}');
    });

    test('returns null for invalid JSON so the caller can leave the text alone', () {
      expect(formatJsonBody('{"a":'), isNull);
    });

    test('returns null when an unquoted variable would be destroyed by re-encoding', () {
      expect(formatJsonBody('{"id":{{id}}}'), isNull);
    });

    test('returns null for an empty body', () {
      expect(formatJsonBody(''), isNull);
    });
  });
}
