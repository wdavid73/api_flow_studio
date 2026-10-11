import 'package:api_flow_studio/cli/cli_options.dart';
import 'package:api_flow_studio/cli/selection.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/workspace/workspace_file.dart';
import 'package:flutter_test/flutter_test.dart';

Environment env(String name, [Map<String, EnvironmentVariable> variables = const {}]) =>
    Environment(id: 'env-$name', name: name, variables: variables);

Flow flow(String id, String name) => Flow(id: id, name: name, steps: const [FlowStep(endpointId: 'e')]);

WorkspaceFile file({List<Environment> envs = const [], List<Flow> flows = const []}) => WorkspaceFile(
      name: 'ws',
      environments: envs,
      flows: flows,
      exportedAt: DateTime.utc(2026),
    );

CliOptions options({
  String? env,
  List<String> flows = const [],
  Map<String, String> vars = const {},
  bool allowProduction = false,
}) =>
    CliOptions(workspace: 'w.json', env: env, flows: flows, vars: vars, allowProduction: allowProduction);

RunSelection ok(WorkspaceFile f, CliOptions o, [Map<String, String> processEnv = const {}]) {
  final result = selectRun(f, o, processEnv);
  expect(result, isA<RunSelection>(), reason: result is SelectionError ? result.message : null);
  return result as RunSelection;
}

String error(WorkspaceFile f, CliOptions o, [Map<String, String> processEnv = const {}]) {
  final result = selectRun(f, o, processEnv);
  expect(result, isA<SelectionError>());
  return (result as SelectionError).message;
}

void main() {
  final oneFlow = [flow('f-1', 'Signup')];

  group('environment', () {
    test('the only environment is used without --env', () {
      expect(ok(file(envs: [env('dev')], flows: oneFlow), options()).environment!.name, 'dev');
    });

    test('--env picks by name, ignoring case', () {
      final s = ok(file(envs: [env('dev'), env('QA')], flows: oneFlow), options(env: 'qa'));

      expect(s.environment!.name, 'QA');
    });

    test('several environments and no --env lists them', () {
      final message = error(file(envs: [env('dev'), env('qa')], flows: oneFlow), options());

      expect(message, contains('--env'));
      expect(message, contains('dev'));
      expect(message, contains('qa'));
    });

    test('an unknown environment lists the available ones', () {
      final message = error(file(envs: [env('dev')], flows: oneFlow), options(env: 'qa'));

      expect(message, contains('"qa"'));
      expect(message, contains('dev'));
    });

    test('no environments and no --env runs with no environment', () {
      final s = ok(file(flows: oneFlow), options(vars: {'a': '1'}));

      expect(s.environment, isNull);
      expect(s.variables, {'a': '1'});
    });

    test('--env on a file with no environments is an error', () {
      expect(error(file(flows: oneFlow), options(env: 'qa')), contains('"qa"'));
    });
  });

  group('production guard', () {
    final prod = file(envs: [env('Production')], flows: oneFlow);

    test('refuses an environment named like production without --allow-production', () {
      final message = error(prod, options());

      expect(message, contains('--allow-production'));
      expect(message, contains('Production'));
    });

    test('lets it through with --allow-production', () {
      expect(ok(prod, options(allowProduction: true)).environment!.name, 'Production');
    });

    test('a name that only contains prod is not production', () {
      expect(ok(file(envs: [env('preprod')], flows: oneFlow), options()).environment!.name, 'preprod');
    });
  });

  group('flows', () {
    final flows = [flow('f-1', 'Signup'), flow('f-2', 'Smoke'), flow('f-3', 'Signup')];

    test('all flows, in file order, when none is named', () {
      final s = ok(file(flows: [flows[0], flows[1]]), options());

      expect(s.flows.map((f) => f.id), ['f-1', 'f-2']);
    });

    test('by name, ignoring case', () {
      expect(ok(file(flows: [flows[1]]), options(flows: ['smoke'])).flows.single.id, 'f-2');
    });

    test('by id', () {
      expect(ok(file(flows: flows), options(flows: ['f-3'])).flows.single.id, 'f-3');
    });

    test('in the order given, without repeats', () {
      final s = ok(file(flows: flows), options(flows: ['f-2', 'f-1', 'f-2']));

      expect(s.flows.map((f) => f.id), ['f-2', 'f-1']);
    });

    test('a name shared by two flows asks for the id', () {
      final message = error(file(flows: flows), options(flows: ['Signup']));

      expect(message, contains('f-1'));
      expect(message, contains('f-3'));
    });

    test('an unknown flow lists the available ones', () {
      final message = error(file(flows: flows), options(flows: ['nope']));

      expect(message, contains('"nope"'));
      expect(message, contains('Smoke'));
    });

    test('a workspace without flows has nothing to run', () {
      expect(error(file(), options()), contains('nothing to run'));
    });
  });

  group('variables', () {
    final secret = {
      'base_url': const EnvironmentVariable(value: 'https://qa.test'),
      'api_key': const EnvironmentVariable(value: '', secret: true),
      'other': const EnvironmentVariable(value: 'kept', secret: true),
    };
    final ws = file(envs: [env('qa', secret)], flows: oneFlow);

    test('start from the environment', () {
      expect(ok(ws, options()).variables['base_url'], 'https://qa.test');
    });

    test('AFS_VAR_<name> overrides the environment', () {
      final s = ok(ws, options(), {'AFS_VAR_base_url': 'https://other', 'PATH': '/bin', 'AFS_VAR_': 'ignored'});

      expect(s.variables['base_url'], 'https://other');
      expect(s.variables.containsKey(''), isFalse);
      expect(s.variables.containsKey('PATH'), isFalse);
    });

    test('--var wins over AFS_VAR_<name>', () {
      final s = ok(ws, options(vars: {'base_url': 'https://cli'}), {'AFS_VAR_base_url': 'https://env'});

      expect(s.variables['base_url'], 'https://cli');
    });

    test('names are case sensitive', () {
      final s = ok(ws, options(), {'AFS_VAR_BASE_URL': 'x'});

      expect(s.variables['base_url'], 'https://qa.test');
      expect(s.variables['BASE_URL'], 'x');
    });

    test('secret variables left empty are reported by name', () {
      expect(ok(ws, options()).emptySecrets, ['api_key']);
    });

    test('a secret given by --var or AFS_VAR is no longer empty', () {
      expect(ok(ws, options(vars: {'api_key': 's3cret'})).emptySecrets, isEmpty);
      expect(ok(ws, options(), {'AFS_VAR_api_key': 's3cret'}).emptySecrets, isEmpty);
    });

    test('knows which names are secret and which values were given from outside', () {
      final s = ok(ws, options(vars: {'api_key': 's3cret'}), {'AFS_VAR_extra': 'from-env'});

      expect(s.secretNames, {'api_key', 'other'});
      expect(s.overrides, {'api_key': 's3cret', 'extra': 'from-env'});
    });
  });
}
