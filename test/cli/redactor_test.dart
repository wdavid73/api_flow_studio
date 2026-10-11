import 'package:api_flow_studio/cli/cli_options.dart';
import 'package:api_flow_studio/cli/redactor.dart';
import 'package:api_flow_studio/cli/selection.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/workspace/workspace_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('redact', () {
    test('replaces every occurrence of a known value', () {
      final r = Redactor(['s3cret-value']);

      expect(r.redact('Bearer s3cret-value and again s3cret-value'), 'Bearer *** and again ***');
    });

    test('leaves text without sensitive values untouched', () {
      expect(Redactor(['s3cret-value']).redact('nothing here'), 'nothing here');
    });

    test('does not mask values shorter than four characters', () {
      expect(Redactor(['1', 'ab', 'abc']).redact('1 ab abc'), '1 ab abc');
      expect(Redactor(['abcd']).redact('abcd'), '***');
    });

    test('ignores empty values', () {
      expect(Redactor(['']).redact('text'), 'text');
    });

    test('masks the longer value first so no tail of it is left behind', () {
      final r = Redactor(['abcd', 'abcd-efgh']);

      expect(r.redact('token=abcd-efgh'), 'token=***');
    });

    test('also finds the percent-encoded form, as it appears in a URL', () {
      final r = Redactor(['p@ss word&1']);

      expect(r.redact('https://x/?k=${Uri.encodeQueryComponent('p@ss word&1')}'), 'https://x/?k=***');
      expect(r.redact('https://x/${Uri.encodeComponent('p@ss word&1')}'), 'https://x/***');
    });

    test('is a plain-text match: an unrelated format of the same secret is not found', () {
      expect(Redactor(['s3cret-value']).redact('S3CRET-VALUE'), 'S3CRET-VALUE');
    });
  });

  group('learn', () {
    test('picks up values extracted into variables with a sensitive name', () {
      final r = Redactor()
        ..learn({
          'access_token': 'tok-1234',
          'API_KEY': 'key-5678',
          'password': 'pw-9012',
          'client_secret': 'sec-3456',
          'authHeader': 'auth-7890',
          'user_id': 'u-0000-1',
        });

      expect(r.redact('tok-1234 key-5678 pw-9012 sec-3456 auth-7890 u-0000-1'), '*** *** *** *** *** u-0000-1');
    });

    test('only affects text redacted afterwards', () {
      final r = Redactor();
      final before = r.redact('tok-1234');

      r.learn({'token': 'tok-1234'});

      expect(before, 'tok-1234');
      expect(r.redact('tok-1234'), '***');
    });
  });

  group('Redactor.forSelection', () {
    final ws = WorkspaceFile(
      name: 'ws',
      environments: const [
        Environment(id: 'e', name: 'qa', variables: {
          'base_url': EnvironmentVariable(value: 'https://qa.test'),
          'api_key': EnvironmentVariable(value: 'file-secret', secret: true),
          'note': EnvironmentVariable(value: 'public text'),
        }),
      ],
      flows: const [Flow(id: 'f', name: 'F', steps: [FlowStep(endpointId: 'x')])],
      exportedAt: DateTime.utc(2026),
    );

    RunSelection select(Map<String, String> vars, [Map<String, String> env = const {}]) =>
        selectRun(ws, CliOptions(workspace: 'w', vars: vars), env) as RunSelection;

    test('masks secret environment values and every value given from outside', () {
      final r = Redactor.forSelection(select({'extra': 'from-cli'}, {'AFS_VAR_other': 'from-env'}));

      expect(r.redact('file-secret from-cli from-env'), '*** *** ***');
    });

    test('does not mask plain environment values', () {
      final r = Redactor.forSelection(select(const {}));

      expect(r.redact('https://qa.test public text'), 'https://qa.test public text');
    });

    test('a secret replaced from outside masks the new value, not the file one', () {
      final r = Redactor.forSelection(select({'api_key': 'given-secret'}));

      expect(r.redact('given-secret'), '***');
    });
  });
}
