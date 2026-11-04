import 'package:api_flow_studio/engine/flows/response_fields.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flattens nested objects into leaf paths with previews', () {
    final r = responseFields({
      'access_token': 'eyJhbGciOiJIUzI1NiJ9.abcdefghijk',
      'user': {'id': 'u_81f', 'age': 3, 'ok': true, 'n': null},
    });

    expect(r.fields.map((f) => f.path), [
      'response.body.access_token',
      'response.body.user.id',
      'response.body.user.age',
      'response.body.user.ok',
      'response.body.user.n',
    ]);
    expect(r.fields[0].preview, '"eyJhbGciOiJIUzI1NiJ9.abc…"');
    expect(r.fields[1].preview, '"u_81f"');
    expect(r.fields[2].preview, '3');
    expect(r.fields[3].preview, 'true');
    expect(r.fields[4].preview, 'null');
    expect(r.omitted, 0);
  });

  test('a list becomes a leaf with its length and only index 0 is expanded', () {
    final r = responseFields({
      'items': [
        {'id': 1},
        {'id': 2},
        {'id': 3},
      ],
    });

    expect(r.fields.map((f) => f.path), ['response.body.items', 'response.body.items.0.id']);
    expect(r.fields.first.listLength, 3);
    expect(r.fields.first.preview, '[3]');
    expect(r.fields.last.listLength, isNull);
  });

  test('an empty list is a leaf with nothing expanded', () {
    final r = responseFields({'items': <Object>[]});

    expect(r.fields.map((f) => f.path), ['response.body.items']);
    expect(r.fields.single.preview, '[0]');
  });

  test('a list at the root uses response.body and response.body.0', () {
    final r = responseFields([
      {'id': 'a'},
    ]);

    expect(r.fields.map((f) => f.path), ['response.body', 'response.body.0.id']);
  });

  test('a scalar, string or missing body has no fields', () {
    expect(responseFields('<html>').fields, isEmpty);
    expect(responseFields(42).fields, isEmpty);
    expect(responseFields(null).fields, isEmpty);
  });

  test('an empty object leaf previews as {}', () {
    final r = responseFields({'meta': <String, Object>{}});

    expect(r.fields.single.path, 'response.body.meta');
    expect(r.fields.single.preview, '{}');
  });

  test('stops at the limit and counts what was left out', () {
    final body = {
      'items': [
        for (var i = 0; i < 1000; i++) {'id': i},
      ],
      'meta': {for (var i = 0; i < 300; i++) 'k$i': i},
    };

    final r = responseFields(body, limit: 200);

    expect(r.fields, hasLength(200));
    expect(r.omitted, 102); // items + items.0.id + 300 keys = 302 leaves
  });

  test('displayPath strips response.body', () {
    expect(displayPath('response.body.user.id'), 'user.id');
    expect(displayPath('response.body'), 'body');
    expect(displayPath('response.status'), 'response.status');
  });

  test('a very deep body does not overflow: containers past the depth limit are leaves', () {
    Object? body = 'bottom';
    for (var i = 0; i < 10000; i++) {
      body = {'a': body};
    }

    final r = responseFields(body);

    expect(r.fields, hasLength(1));
    expect(r.fields.single.path.split('.'), hasLength(maxFieldDepth + 2)); // response.body + the levels walked
    expect(r.fields.single.preview, '{…}');
  });

  test('a very deep body past the limit is only counted, without overflowing', () {
    Object? deep = 'bottom';
    for (var i = 0; i < 10000; i++) {
      deep = [deep];
    }

    final r = responseFields({'first': 1, 'deep': deep}, limit: 1);

    expect(r.fields.single.path, 'response.body.first');
    expect(r.omitted, greaterThan(0));
  });
}
