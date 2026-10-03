import 'package:api_flow_studio/engine/hosts/host_matrix.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Environment env(String id, String name, Map<String, String> urls, {Set<String> secret = const {}}) => Environment(
      id: id,
      name: name,
      variables: {
        for (final e in urls.entries) e.key: EnvironmentVariable(value: e.value, secret: secret.contains(e.key)),
      },
    );

Endpoint endpoint(String url, {String id = 'e'}) =>
    Endpoint(id: id, groupId: 'g', name: id, method: 'GET', url: url);

void main() {
  group('isHostUrl', () {
    test('accepts http and https, any case, with surrounding spaces', () {
      expect(isHostUrl('http://x.test'), isTrue);
      expect(isHostUrl('https://x.test/api'), isTrue);
      expect(isHostUrl('  HTTPS://X.TEST '), isTrue);
    });

    test('rejects everything else', () {
      for (final value in ['', '   ', '{{base}}/api', 'ftp://x.test', 'x.test', 'httpx://x', 'abc']) {
        expect(isHostUrl(value), isFalse, reason: value);
      }
    });
  });

  group('buildHostMatrix', () {
    final dev = env('dev', 'Dev', {'AUTH': 'https://dev/auth', 'MARKET': 'https://dev/market', 'timeout': '30'});
    final qa = env('qa', 'QA', {'AUTH': 'https://qa/auth'});
    final prod = env('prod', 'Prod', {'AUTH': 'https://prod/auth', 'MARKET': 'https://prod/market'});

    HostMatrix build({
      List<Environment>? environments,
      List<Endpoint> endpoints = const [],
      Map<String, String> notes = const {},
    }) =>
        buildHostMatrix(environments ?? [dev, qa, prod], endpoints, notes);

    test('a URL variable becomes a row and non-URL variables are ignored', () {
      final matrix = build();

      expect(matrix.rows.map((r) => r.name), ['AUTH', 'MARKET']);
    });

    test('columns keep the environment order', () {
      expect(build(environments: [prod, dev, qa]).environments.map((e) => e.id), ['prod', 'dev', 'qa']);
    });

    test('rows are sorted by name', () {
      final matrix = build(environments: [env('a', 'A', {'zeta': 'https://z', 'Alpha': 'https://a', 'mid': 'https://m'})]);

      expect(matrix.rows.map((r) => r.name), ['Alpha', 'mid', 'zeta']);
    });

    test('values are looked up per environment', () {
      final auth = build().rows.first;

      expect(auth.valueIn('dev'), 'https://dev/auth');
      expect(auth.valueIn('qa'), 'https://qa/auth');
      expect(auth.valueIn('prod'), 'https://prod/auth');
    });

    test('an environment that lacks the variable is listed as missing', () {
      final market = build().rows.last;

      expect(market.valueIn('qa'), isNull);
      expect(market.missingEnvironmentIds, ['qa']);
    });

    test('a base present everywhere has nothing missing', () {
      expect(build().rows.first.missingEnvironmentIds, isEmpty);
    });

    test('an empty or blank value counts as missing', () {
      final matrix = build(environments: [
        env('a', 'A', {'X': 'https://x'}),
        env('b', 'B', {'X': '   '}),
      ]);

      expect(matrix.rows.single.valueIn('b'), isNull);
      expect(matrix.rows.single.missingEnvironmentIds, ['b']);
    });

    test('a variable is a base when at least one environment gives a URL, even if others do not', () {
      final matrix = build(environments: [
        env('a', 'A', {'X': 'https://x'}),
        env('b', 'B', {'X': 'not a url'}),
      ]);

      expect(matrix.rows.map((r) => r.name), ['X']);
      expect(matrix.rows.single.valueIn('b'), 'not a url');
    });

    test('a variable that is secret in any environment is never a row', () {
      final matrix = build(environments: [
        env('a', 'A', {'KEY': 'https://secret-host'}, secret: {'KEY'}),
        env('b', 'B', {'KEY': 'https://other'}),
        env('c', 'C', {'OK': 'https://ok'}),
      ]);

      expect(matrix.rows.map((r) => r.name), ['OK']);
    });

    test('a variable that is never a URL is never a row', () {
      expect(build(environments: [env('a', 'A', {'timeout': '30', 'name': 'x'})]).rows, isEmpty);
    });

    test('usedBy counts the endpoints whose URL contains {{name}}', () {
      final matrix = build(endpoints: [
        endpoint('{{AUTH}}/login', id: '1'),
        endpoint('{{AUTH}}/logout', id: '2'),
        endpoint('{{MARKET}}/items', id: '3'),
        endpoint('https://literal.test', id: '4'),
        endpoint('{{AUTHORS}}/x', id: '5'),
        endpoint('{{ AUTH }}/spaced', id: '6'),
      ]);

      expect(matrix.rows.first.usedBy, 2);
      expect(matrix.rows.last.usedBy, 1);
    });

    test('notes are attached by name and default to empty', () {
      final matrix = build(notes: {'AUTH': 'Identity: login and sessions'});

      expect(matrix.rows.first.note, 'Identity: login and sessions');
      expect(matrix.rows.last.note, '');
    });

    test('no environments or no variables gives no rows', () {
      expect(build(environments: const []).rows, isEmpty);
      expect(build(environments: [env('a', 'A', {})]).rows, isEmpty);
    });

    test('rows that are missing somewhere are found with isMissingSomewhere', () {
      final matrix = build();

      expect(matrix.rows.first.isMissingSomewhere, isFalse);
      expect(matrix.rows.last.isMissingSomewhere, isTrue);
    });
  });
}
