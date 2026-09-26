import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/variables/interpolator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('interpolate', () {
    test('replaces a variable at the start of the string', () {
      expect(interpolate('{{base_url}}/users', {'base_url': 'https://api.dev'}),
          'https://api.dev/users');
    });

    test('replaces a variable at the end of the string', () {
      expect(interpolate('Bearer {{token}}', {'token': 'abc123'}), 'Bearer abc123');
    });

    test('replaces a variable in the middle of the string', () {
      expect(interpolate('/users/{{id}}/profile', {'id': '42'}), '/users/42/profile');
    });

    test('replaces multiple variables in one string', () {
      expect(
        interpolate('{{scheme}}://{{host}}/v1', {'scheme': 'https', 'host': 'api.dev'}),
        'https://api.dev/v1',
      );
    });

    test('returns the template unchanged when it has no variables', () {
      expect(interpolate('/users/42', {'id': '42'}), '/users/42');
    });

    test('leaves an unresolved variable literal instead of blanking it', () {
      expect(interpolate('{{missing}}/users', {}), '{{missing}}/users');
    });

    test('leaves a malformed unclosed token untouched', () {
      expect(interpolate('{{unclosed/users', {'unclosed': 'x'}), '{{unclosed/users');
    });

    test('matches variable names with underscores and digits', () {
      expect(interpolate('{{user_id_2}}', {'user_id_2': '99'}), '99');
    });
  });

  group('interpolateEntries', () {
    test('interpolates key and value of enabled entries', () {
      final result = interpolateEntries(
        [const KeyValueEntry(key: 'Authorization', value: 'Bearer {{token}}')],
        {'token': 'abc123'},
      );

      expect(result.single.value, 'Bearer abc123');
    });

    test('leaves disabled entries un-interpolated but present', () {
      final result = interpolateEntries(
        [const KeyValueEntry(key: 'X-Debug', value: '{{token}}', enabled: false)],
        {'token': 'abc123'},
      );

      expect(result.single.value, '{{token}}');
      expect(result.single.enabled, isFalse);
    });
  });

  group('interpolateBody', () {
    test('none stays none', () {
      expect(interpolateBody(const RequestBody.none(), const {}), const RequestBody.none());
    });

    test('interpolates variables inside a json body', () {
      final result = interpolateBody(
        const RequestBody.json('{"email":"{{user_email}}"}'),
        {'user_email': 'a@b.com'},
      );

      expect(result, const RequestBody.json('{"email":"a@b.com"}'));
    });

    test('interpolates enabled fields of a formUrlEncoded body', () {
      final result = interpolateBody(
        const RequestBody.formUrlEncoded([
          KeyValueEntry(key: 'refresh_token', value: '{{refresh_token}}'),
        ]),
        {'refresh_token': 'rtok'},
      );

      final fields = result.maybeMap(
        formUrlEncoded: (b) => b.fields,
        orElse: () => const <KeyValueEntry>[],
      );
      expect(fields.single.value, 'rtok');
    });
  });
}
