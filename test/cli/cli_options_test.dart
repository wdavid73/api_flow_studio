import 'package:api_flow_studio/cli/cli_options.dart';
import 'package:flutter_test/flutter_test.dart';

CliOptions ok(List<String> args) {
  final result = parseCliArgs(args);
  expect(result, isA<CliOptions>(), reason: result is CliUsageError ? result.message : null);
  return result as CliOptions;
}

String usageError(List<String> args) {
  final result = parseCliArgs(args);
  expect(result, isA<CliUsageError>(), reason: 'expected "${args.join(' ')}" to be rejected');
  return (result as CliUsageError).message;
}

void main() {
  group('defaults', () {
    test('only --workspace is needed', () {
      final o = ok(['--workspace', 'a.workspace.json']);

      expect(o.workspace, 'a.workspace.json');
      expect(o.env, isNull);
      expect(o.flows, isEmpty);
      expect(o.vars, isEmpty);
      expect(o.timeout, const Duration(seconds: 30));
      expect(o.failFast, isFalse);
      expect(o.allowProduction, isFalse);
      expect(o.junit, isNull);
      expect(o.json, isNull);
      expect(o.verbose, isFalse);
      expect(o.list, isFalse);
      expect(o.help, isFalse);
    });
  });

  group('options', () {
    test('short forms', () {
      final o = ok(['-w', 'a.json', '-e', 'qa', '-f', 'Signup', '-v']);

      expect(o.workspace, 'a.json');
      expect(o.env, 'qa');
      expect(o.flows, ['Signup']);
      expect(o.verbose, isTrue);
    });

    test('--flow is repeatable and keeps the order', () {
      expect(ok(['-w', 'a.json', '--flow', 'B', '--flow', 'A']).flows, ['B', 'A']);
    });

    test('--var is repeatable, splits on the first =, and the last one wins', () {
      final o = ok(['-w', 'a.json', '--var', 'a=1', '--var', 'url=https://x/?q=1', '--var', 'a=2', '--var', 'empty=']);

      expect(o.vars, {'a': '2', 'url': 'https://x/?q=1', 'empty': ''});
    });

    test('switches', () {
      final o = ok(['-w', 'a.json', '--fail-fast', '--allow-production', '--list']);

      expect(o.failFast, isTrue);
      expect(o.allowProduction, isTrue);
      expect(o.list, isTrue);
    });

    test('report files', () {
      final o = ok(['-w', 'a.json', '--junit', 'r.xml', '--json', 'r.json']);

      expect(o.junit, 'r.xml');
      expect(o.json, 'r.json');
    });

    test('--timeout takes seconds, also decimal', () {
      expect(ok(['-w', 'a.json', '--timeout', '5']).timeout, const Duration(seconds: 5));
      expect(ok(['-w', 'a.json', '--timeout', '0.5']).timeout, const Duration(milliseconds: 500));
    });
  });

  group('help', () {
    test('--help needs nothing else', () {
      expect(ok(['--help']).help, isTrue);
      expect(ok(['-h']).help, isTrue);
    });

    test('usageText names every option', () {
      for (final option in ['--workspace', '--env', '--flow', '--var', '--timeout', '--fail-fast', '--allow-production', '--junit', '--json', '--verbose', '--list', '--help']) {
        expect(usageText, contains(option), reason: option);
      }
    });
  });

  group('usage errors', () {
    test('no arguments asks for --workspace', () {
      expect(usageError([]), contains('--workspace'));
    });

    test('--list without --workspace', () {
      expect(usageError(['--list']), contains('--workspace'));
    });

    test('an unknown option is named', () {
      expect(usageError(['-w', 'a.json', '--nope']), contains('--nope'));
    });

    test('an option without its value', () {
      expect(usageError(['-w']), contains('-w'));
      expect(usageError(['-w', 'a.json', '--env']), contains('--env'));
    });

    test('a stray positional argument', () {
      expect(usageError(['-w', 'a.json', 'extra']), contains('extra'));
    });

    test('--var must be name=value with a name', () {
      expect(usageError(['-w', 'a.json', '--var', 'novalue']), contains('novalue'));
      expect(usageError(['-w', 'a.json', '--var', '=x']), contains('=x'));
    });

    test('--timeout must be a positive number', () {
      for (final bad in ['0', '-1', 'abc', '']) {
        expect(usageError(['-w', 'a.json', '--timeout', bad]), contains('--timeout'), reason: bad);
      }
    });
  });
}
