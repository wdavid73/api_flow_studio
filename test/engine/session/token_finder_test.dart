import 'package:api_flow_studio/engine/session/token_finder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds camelCase tokens at the root', () {
    final found = findTokens({'accessToken': 'a', 'refreshToken': 'r'});

    expect(found.accessToken, 'a');
    expect(found.refreshToken, 'r');
  });

  test('finds snake_case tokens', () {
    final found = findTokens({'access_token': 'a', 'refresh_token': 'r'});

    expect(found.accessToken, 'a');
    expect(found.refreshToken, 'r');
  });

  test('finds tokens nested inside objects', () {
    final found = findTokens({
      'status': 'ok',
      'data': {
        'session': {'accessToken': 'deep-a', 'refreshToken': 'deep-r'},
      },
    });

    expect(found.accessToken, 'deep-a');
    expect(found.refreshToken, 'deep-r');
  });

  test('finds tokens inside arrays', () {
    final found = findTokens({
      'results': [
        {'id': 1},
        {'accessToken': 'in-list'},
      ],
    });

    expect(found.accessToken, 'in-list');
  });

  test('returns only the token that is present', () {
    expect(findTokens({'accessToken': 'a'}).refreshToken, isNull);
    expect(findTokens({'refreshToken': 'r'}).accessToken, isNull);
  });

  test('returns nulls when there are none or the input is not a container', () {
    for (final input in [<String, Object?>{}, <Object?>[], 'text', 42, null, true]) {
      final found = findTokens(input);

      expect(found.accessToken, isNull, reason: '$input');
      expect(found.refreshToken, isNull, reason: '$input');
    }
  });

  test('ignores values that are not non-blank strings', () {
    final found = findTokens({'accessToken': 123, 'refresh_token': '   ', 'refreshToken': null});

    expect(found.accessToken, isNull);
    expect(found.refreshToken, isNull);
  });

  test('prefers the shallowest match', () {
    final found = findTokens({
      'data': {'accessToken': 'deep'},
      'accessToken': 'top',
    });

    expect(found.accessToken, 'top');
  });

  test('camelCase wins over snake_case in the same object', () {
    expect(findTokens({'access_token': 'snake', 'accessToken': 'camel'}).accessToken, 'camel');
  });

  test('stops after 300 nodes', () {
    List<Object?> fillers(int n) => [for (var i = 0; i < n; i++) <String, Object?>{}];

    // The root is node 1, then the fillers, then the token holder.
    final found300 = findTokens(fillers(298) + [<String, Object?>{'accessToken': 'last-reachable'}]);
    final found301 = findTokens(fillers(299) + [<String, Object?>{'accessToken': 'too-far'}]);

    expect(found300.accessToken, 'last-reachable');
    expect(found301.accessToken, isNull);
  });

  test('a very deep tree does not overflow the stack', () {
    Object? deep = <String, Object?>{'accessToken': 'bottom'};
    for (var i = 0; i < 100000; i++) {
      deep = <String, Object?>{'next': deep};
    }

    expect(() => findTokens(deep), returnsNormally);
    expect(findTokens(deep).accessToken, isNull);
  });
}
