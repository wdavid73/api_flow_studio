import 'package:api_flow_studio/engine/hosts/host_matrix.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = Environment(
    id: 'dev',
    name: 'Dev',
    variables: {
      'AUTH': EnvironmentVariable(value: 'https://dev/auth'),
      'timeout': EnvironmentVariable(value: '30'),
      'KEY': EnvironmentVariable(value: 'https://keyed', secret: true),
    },
  );

  test('creates the variable when it is absent', () {
    final next = setHostValue(base, 'MARKET', 'https://dev/market');

    expect(next.variables['MARKET']!.value, 'https://dev/market');
    expect(next.variables['MARKET']!.secret, isFalse);
  });

  test('replaces the value of an existing variable', () {
    expect(setHostValue(base, 'AUTH', 'https://new/auth').variables['AUTH']!.value, 'https://new/auth');
  });

  test('an empty value removes the variable', () {
    final next = setHostValue(base, 'AUTH', '');

    expect(next.variables.containsKey('AUTH'), isFalse);
  });

  test('a whitespace-only value removes the variable too', () {
    expect(setHostValue(base, 'AUTH', '   ').variables.containsKey('AUTH'), isFalse);
  });

  test('every other variable and the environment identity are untouched', () {
    final next = setHostValue(base, 'AUTH', 'https://new/auth');

    expect(next.id, 'dev');
    expect(next.name, 'Dev');
    expect(next.variables['timeout'], base.variables['timeout']);
    expect(next.variables['KEY'], base.variables['KEY']);
    expect(next.variables.keys.toSet(), base.variables.keys.toSet());
  });

  test('keeps the secret flag of an existing variable when replacing its value', () {
    final next = setHostValue(base, 'KEY', 'https://changed');

    expect(next.variables['KEY']!.secret, isTrue);
    expect(next.variables['KEY']!.value, 'https://changed');
  });

  test('removing a variable that does not exist returns an equal environment', () {
    expect(setHostValue(base, 'NOPE', ''), base);
  });

  test('the input environment is not modified', () {
    setHostValue(base, 'AUTH', '');

    expect(base.variables.containsKey('AUTH'), isTrue);
  });

  test('the value is stored as typed, without trimming inner content', () {
    expect(setHostValue(base, 'AUTH', 'https://x.test/a b').variables['AUTH']!.value, 'https://x.test/a b');
  });
}
