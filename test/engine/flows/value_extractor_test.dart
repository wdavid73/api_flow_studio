import 'package:api_flow_studio/engine/flows/value_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractValue', () {
    test('resolves a deeply nested object path', () {
      final response = {
        'status': 200,
        'headers': <String, String>{},
        'body': {
          'data': {'otp': '123456'},
        },
      };

      expect(extractValue(response, 'response.body.data.otp'), '123456');
    });

    test('resolves an array-index path', () {
      final response = {
        'status': 200,
        'headers': <String, String>{},
        'body': {
          'items': [
            {'id': 'a'},
            {'id': 'b'},
          ],
        },
      };

      expect(extractValue(response, 'response.body.items.1.id'), 'b');
    });

    test('returns null for a missing key at any depth', () {
      final response = {
        'status': 200,
        'headers': <String, String>{},
        'body': {'data': {}},
      };

      expect(extractValue(response, 'response.body.data.missing'), isNull);
      expect(extractValue(response, 'response.body.missing.deep'), isNull);
    });

    test('returns null for an out-of-range array index', () {
      final response = {
        'status': 200,
        'headers': <String, String>{},
        'body': {
          'items': [1, 2],
        },
      };

      expect(extractValue(response, 'response.body.items.5'), isNull);
      expect(extractValue(response, 'response.body.items.-1'), isNull);
    });

    test('returns null instead of throwing when the body is a non-JSON string', () {
      final response = {
        'status': 200,
        'headers': <String, String>{},
        'body': '<html>not json</html>',
      };

      expect(extractValue(response, 'response.body.data.otp'), isNull);
    });

    test('returns the top-level status via a shallow path', () {
      final response = {'status': 404, 'headers': <String, String>{}, 'body': null};

      expect(extractValue(response, 'response.status'), 404);
    });

    test('throws ArgumentError for a path not rooted at "response"', () {
      expect(
        () => extractValue({'status': 200, 'headers': {}, 'body': null}, 'body.data'),
        throwsArgumentError,
      );
    });
  });

  group('extractValueAsString', () {
    Map<String, dynamic> responseWithBody(dynamic body) =>
        {'status': 200, 'headers': <String, String>{}, 'body': body};

    test('a string value passes through unchanged', () {
      expect(
        extractValueAsString(responseWithBody({'otp': 'abc'}), 'response.body.otp'),
        'abc',
      );
    });

    test('a number is stringified', () {
      expect(
        extractValueAsString(responseWithBody({'count': 42}), 'response.body.count'),
        '42',
      );
    });

    test('a boolean is stringified', () {
      expect(
        extractValueAsString(responseWithBody({'active': true}), 'response.body.active'),
        'true',
      );
    });

    test('an object is JSON-encoded', () {
      expect(
        extractValueAsString(responseWithBody({'user': {'id': 1}}), 'response.body.user'),
        '{"id":1}',
      );
    });

    test('a list is JSON-encoded', () {
      expect(
        extractValueAsString(responseWithBody({'tags': ['a', 'b']}), 'response.body.tags'),
        '["a","b"]',
      );
    });

    test('a missing value is null', () {
      expect(
        extractValueAsString(responseWithBody({}), 'response.body.missing'),
        isNull,
      );
    });
  });
}
