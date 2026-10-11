import 'dart:math';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/variables/dynamic_values.dart';
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

  group('dynamic tokens', () {
    DynamicValues dyn() => DynamicValues(random: Random(1));

    test('replaces a known token with a generated value', () {
      final out = interpolate('id={{\$uuid}}', {}, dynamicValues: dyn());
      expect(out, matches(RegExp(r'^id=[0-9a-f-]{36}$')));
    });

    test('generates a different value for each occurrence', () {
      final out = interpolate(
        '{{\$uuid}} {{\$uuid}}',
        {},
        dynamicValues: dyn(),
      );
      final parts = out.split(' ');
      expect(parts, hasLength(2));
      expect(parts[0], isNot(parts[1]));
    });

    test('leaves an unknown token literal', () {
      expect(interpolate('{{\$nope}}', {}, dynamicValues: dyn()), '{{\$nope}}');
    });

    test('leaves the token literal when no generator is given', () {
      expect(interpolate('{{\$uuid}}', {}), '{{\$uuid}}');
    });

    test('does not change normal variables', () {
      expect(
        interpolate(
          '{{a}}-{{\$timestamp}}',
          {'a': 'x'},
          dynamicValues: DynamicValues(now: () => DateTime.utc(2026)),
        ),
        'x-1767225600',
      );
    });

    test('a variable value containing a token is resolved', () {
      final out = interpolate('{{run_id}}', {
        'run_id': '{{\$randomInt}}',
      }, dynamicValues: dyn());
      expect(out, matches(RegExp(r'^\d+$')));
    });

    test('generated values are not scanned again', () {
      final out = interpolate('{{\$randomString}}', {}, dynamicValues: dyn());
      expect(out, isNot(contains('{{')));
    });

    test('interpolateEntries resolves tokens in enabled entries only', () {
      final result = interpolateEntries(
        [
          const KeyValueEntry(key: 'X-Id', value: '{{\$uuid}}'),
          const KeyValueEntry(
            key: 'X-Off',
            value: '{{\$uuid}}',
            enabled: false,
          ),
        ],
        {},
        dynamicValues: dyn(),
      );
      expect(result[0].value, isNot(contains('{{')));
      expect(result[1].value, '{{\$uuid}}');
    });

    test('interpolateBody resolves tokens in json and form bodies', () {
      final json = interpolateBody(
        const RequestBody.json('{"e":"{{\$randomEmail}}","n":{{\$randomInt}}}'),
        {},
        dynamicValues: dyn(),
      );
      final raw = json.maybeMap(json: (b) => b.raw, orElse: () => '');
      expect(raw, isNot(contains('{{')));

      final form = interpolateBody(
        const RequestBody.formUrlEncoded([
          KeyValueEntry(key: 'k', value: '{{\$uuid}}'),
        ]),
        {},
        dynamicValues: dyn(),
      );
      final value = form.maybeMap(
        formUrlEncoded: (b) => b.fields.single.value,
        orElse: () => '',
      );
      expect(value, isNot(contains('{{')));
    });
  });

  group('interpolateBody multipart', () {
    final dyn = DynamicValues(random: Random(1));

    List<MultipartField> fieldsOf(RequestBody body) =>
        body.maybeMap(multipart: (b) => b.fields, orElse: () => throw StateError('not multipart'));

    test('resolves name, text, path and content type of enabled fields', () {
      final result = interpolateBody(
        const RequestBody.multipart([
          MultipartField(name: '{{field}}', value: 'Hi {{who}}'),
          MultipartField(name: 'file', kind: MultipartFieldKind.file, value: '{{dir}}/a.png', contentType: '{{type}}'),
        ]),
        {'field': 'title', 'who': 'Ana', 'dir': '/tmp', 'type': 'image/png'},
      );

      expect(fieldsOf(result), [
        const MultipartField(name: 'title', value: 'Hi Ana'),
        const MultipartField(name: 'file', kind: MultipartFieldKind.file, value: '/tmp/a.png', contentType: 'image/png'),
      ]);
    });

    test('leaves a disabled field untouched', () {
      final result = interpolateBody(
        const RequestBody.multipart([MultipartField(name: 'a', value: '{{x}}', enabled: false)]),
        {'x': '1'},
      );

      expect(fieldsOf(result).single.value, '{{x}}');
    });

    test('keeps kind, enabled and a null content type', () {
      final result = interpolateBody(
        const RequestBody.multipart([MultipartField(name: 'a', kind: MultipartFieldKind.file, value: 'p')]),
        const {},
      );

      final field = fieldsOf(result).single;
      expect(field.kind, MultipartFieldKind.file);
      expect(field.contentType, isNull);
      expect(field.enabled, isTrue);
    });

    test('resolves {{\$tokens}} with a generator and leaves them without one', () {
      const body = RequestBody.multipart([MultipartField(name: 'id', value: '{{\$uuid}}')]);

      expect(fieldsOf(interpolateBody(body, const {}, dynamicValues: dyn)).single.value, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(fieldsOf(interpolateBody(body, const {})).single.value, '{{\$uuid}}');
    });
  });
}
