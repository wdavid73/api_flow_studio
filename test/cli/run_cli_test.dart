import 'dart:convert';
import 'dart:io';

import 'package:api_flow_studio/cli/run_cli.dart';
import 'package:api_flow_studio/engine/http/executed_response.dart';
import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/workspace/workspace_file.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers by endpoint id and remembers what it was asked.
class FakeExecutor implements RequestExecutor {
  FakeExecutor(this.routes);

  final Map<String, ExecutedResponse Function(Map<String, String> variables)> routes;
  final List<String> calls = [];
  final List<Map<String, String>> variablesSeen = [];

  @override
  Future<ExecutedResponse> execute(Endpoint endpoint, {required Map<String, String> variables}) async {
    calls.add(endpoint.id);
    variablesSeen.add(variables);
    return routes[endpoint.id]?.call(variables) ?? const ExecutedResponse(status: 200, elapsedMs: 5);
  }
}

Endpoint _endpoint(String id, String name) =>
    Endpoint(id: id, groupId: 'g', name: name, method: 'GET', url: '{{base_url}}/$id');

WorkspaceFile _workspace({
  List<Environment>? environments,
  List<Flow>? flows,
}) =>
    WorkspaceFile(
      name: 'commodo',
      environments: environments ??
          const [
            Environment(id: 'e-qa', name: 'qa', variables: {
              'base_url': EnvironmentVariable(value: 'https://qa.test'),
              'api_key': EnvironmentVariable(value: '', secret: true),
            }),
          ],
      endpoints: [_endpoint('login', 'Log in'), _endpoint('items', 'List items'), _endpoint('boom', 'Boom')],
      flows: flows ??
          const [
            Flow(id: 'f-a', name: 'Alpha', steps: [FlowStep(endpointId: 'login'), FlowStep(endpointId: 'items')]),
            Flow(id: 'f-b', name: 'Beta', steps: [FlowStep(endpointId: 'items')]),
          ],
      exportedAt: DateTime.utc(2026),
    );

void main() {
  late Directory tmp;
  late StringBuffer out;
  late StringBuffer err;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('run_cli_test_');
    out = StringBuffer();
    err = StringBuffer();
  });

  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Future<String> write(WorkspaceFile ws, [String name = 'ws.workspace.json']) async {
    final file = File('${tmp.path}/$name');
    await file.writeAsString(ws.encode());
    return file.path;
  }

  Future<int> run(List<String> args, {FakeExecutor? executor, Map<String, String> env = const {}}) => runCli(
        args,
        out: out,
        err: err,
        environment: env,
        executor: executor ?? FakeExecutor({}),
        now: () => DateTime.utc(2026, 10, 11, 14, 3, 22),
      );

  group('a run', () {
    test('where everything passes exits 0 and says so', () async {
      final path = await write(_workspace());
      final executor = FakeExecutor({});

      final code = await run(['-w', path, '-e', 'qa'], executor: executor);

      expect(code, 0);
      expect(out.toString(), contains('Flow: Alpha (2 steps)'));
      expect(out.toString(), contains('[PASS] 1. Log in'));
      expect(out.toString(), contains('[PASS] 2. List items'));
      expect(out.toString(), contains('Flow: Beta (1 step)'));
      expect(out.toString(), contains('2 flows: 2 passed, 0 failed'));
      expect(executor.calls, ['login', 'items', 'items']);
    });

    test('starts every flow from the environment variables plus the overrides', () async {
      final path = await write(_workspace());
      final executor = FakeExecutor({});

      await run(['-w', path, '-e', 'qa', '--var', 'api_key=k-12345'], executor: executor, env: {'AFS_VAR_base_url': 'https://override'});

      expect(executor.variablesSeen.first['base_url'], 'https://override');
      expect(executor.variablesSeen.first['api_key'], 'k-12345');
    });

    test('a failed assertion exits 1, shows why, and skips the steps after it', () async {
      final ws = _workspace(flows: const [
        Flow(id: 'f-a', name: 'Alpha', steps: [
          FlowStep(endpointId: 'login', assertions: [Assertion(field: 'response.status', expected: '201')]),
          FlowStep(endpointId: 'items'),
        ]),
      ]);
      final executor = FakeExecutor({});

      final code = await run(['-w', await write(ws), '-e', 'qa'], executor: executor);

      expect(code, 1);
      expect(out.toString(), contains('[FAIL] 1. Log in'));
      expect(out.toString(), contains('Assertion failed: expected response.status == "201", got "200"'));
      expect(out.toString(), contains('[SKIP] 2. List items'));
      expect(out.toString(), contains('1 flow: 0 passed, 1 failed'));
      expect(executor.calls, ['login']);
      // A failing run is not an error of the runner: only the empty-secret warning is on stderr.
      expect(err.toString(), isNot(contains('error:')));
    });

    test('a network error exits 1', () async {
      final ws = _workspace(flows: const [
        Flow(id: 'f-a', name: 'Alpha', steps: [FlowStep(endpointId: 'boom')]),
      ]);
      final executor = FakeExecutor({'boom': (_) => const ExecutedResponse(error: 'Connection refused')});

      final code = await run(['-w', await write(ws), '-e', 'qa'], executor: executor);

      expect(code, 1);
      expect(out.toString(), contains('Connection refused'));
    });

    test('a flow pointing at an endpoint that is not in the file fails with a configuration error', () async {
      final ws = _workspace(flows: const [
        Flow(id: 'f-a', name: 'Alpha', steps: [FlowStep(endpointId: 'ghost')]),
      ]);

      final code = await run(['-w', await write(ws), '-e', 'qa']);

      expect(code, 1);
      expect(out.toString(), contains('Missing endpoint (ghost)'));
    });

    test('--fail-fast does not run the flows after the first failure', () async {
      final executor = FakeExecutor({'login': (_) => const ExecutedResponse(error: 'down')});

      final code = await run(['-w', await write(_workspace()), '-e', 'qa', '--fail-fast'], executor: executor);

      expect(code, 1);
      expect(executor.calls, ['login']);
      expect(out.toString(), isNot(contains('Flow: Beta')));
      expect(out.toString(), contains('1 flow: 0 passed, 1 failed'));
    });

    test('without --fail-fast every flow runs', () async {
      final executor = FakeExecutor({'login': (_) => const ExecutedResponse(error: 'down')});

      await run(['-w', await write(_workspace()), '-e', 'qa'], executor: executor);

      expect(out.toString(), contains('Flow: Beta'));
      expect(executor.calls, ['login', 'items']);
    });

    test('--flow runs just that flow', () async {
      final executor = FakeExecutor({});

      await run(['-w', await write(_workspace()), '-e', 'qa', '--flow', 'beta'], executor: executor);

      expect(executor.calls, ['items']);
    });

    test('--verbose prints the request line of each step', () async {
      final executor = FakeExecutor({'login': (_) => const ExecutedResponse(status: 200, requestUrl: 'https://qa.test/login')});

      await run(['-w', await write(_workspace()), '-e', 'qa', '--flow', 'Alpha', '-v'], executor: executor);

      expect(out.toString(), contains('GET https://qa.test/login'));
    });

    test('warns on stderr about a secret variable with no value, and keeps going', () async {
      final code = await run(['-w', await write(_workspace()), '-e', 'qa']);

      expect(code, 0);
      expect(err.toString(), contains('warning: secret variable "api_key" has no value'));
    });

    test('no warning once the secret is given', () async {
      await run(['-w', await write(_workspace()), '-e', 'qa'], env: {'AFS_VAR_api_key': 'k-12345'});

      expect(err.toString(), isEmpty);
    });
  });

  group('runs that cannot start exit 2 without sending anything', () {
    late FakeExecutor executor;
    setUp(() => executor = FakeExecutor({}));

    test('a usage error says what is wrong', () async {
      final code = await run(['--nope'], executor: executor);

      expect(code, 2);
      expect(err.toString(), startsWith('error: '));
      expect(err.toString(), contains('--help'));
      expect(out.toString(), isEmpty);
    });

    test('a file that does not exist', () async {
      final code = await run(['-w', '${tmp.path}/nope.json'], executor: executor);

      expect(code, 2);
      expect(err.toString(), contains('cannot read'));
      expect(err.toString(), contains('nope.json'));
    });

    test('a file that is not a workspace', () async {
      final file = File('${tmp.path}/x.json')..writeAsStringSync('{"hello": 1}');

      final code = await run(['-w', file.path], executor: executor);

      expect(code, 2);
      expect(err.toString(), contains('not an API Flow Studio workspace'));
    });

    test('a workspace from a newer version', () async {
      final file = File('${tmp.path}/x.json')
        ..writeAsStringSync(jsonEncode({'format': 'api-flow-studio-workspace', 'version': workspaceFormatVersion + 1, 'project': {'name': 'x'}}));

      final code = await run(['-w', file.path], executor: executor);

      expect(code, 2);
      expect(err.toString(), contains('newer version'));
    });

    test('several environments and none chosen', () async {
      final ws = _workspace(environments: const [Environment(id: '1', name: 'qa'), Environment(id: '2', name: 'dev')]);

      final code = await run(['-w', await write(ws)], executor: executor);

      expect(code, 2);
      expect(err.toString(), contains('--env'));
      expect(executor.calls, isEmpty);
    });

    test('an unknown flow', () async {
      final code = await run(['-w', await write(_workspace()), '-e', 'qa', '-f', 'nope'], executor: executor);

      expect(code, 2);
      expect(err.toString(), contains('"nope"'));
      expect(executor.calls, isEmpty);
    });

    test('production without --allow-production', () async {
      final ws = _workspace(environments: const [Environment(id: 'p', name: 'prod')]);

      final code = await run(['-w', await write(ws), '-e', 'prod'], executor: executor);

      expect(code, 2);
      expect(err.toString(), contains('--allow-production'));
      expect(executor.calls, isEmpty);
    });

    test('production with --allow-production runs', () async {
      final ws = _workspace(environments: const [Environment(id: 'p', name: 'prod')]);

      final code = await run(['-w', await write(ws), '-e', 'prod', '--allow-production'], executor: executor);

      expect(code, 0);
      expect(executor.calls, isNotEmpty);
    });
  });

  group('--help and --list', () {
    test('--help prints the usage and exits 0', () async {
      final code = await run(['--help']);

      expect(code, 0);
      expect(out.toString(), contains('Usage: api_flow_runner'));
      expect(out.toString(), contains('--workspace'));
    });

    test('--list prints environments and flows, sends nothing and exits 0', () async {
      final executor = FakeExecutor({});

      final code = await run(['-w', await write(_workspace()), '--list'], executor: executor);

      expect(code, 0);
      expect(out.toString(), contains('Environments:\n  qa'));
      expect(out.toString(), contains('Alpha (f-a, 2 steps)'));
      expect(out.toString(), contains('Beta (f-b, 1 step)'));
      expect(executor.calls, isEmpty);
    });

    test('--list does not need an environment, even a production one', () async {
      final ws = _workspace(environments: const [Environment(id: 'p', name: 'prod'), Environment(id: 'q', name: 'qa')]);

      expect(await run(['-w', await write(ws), '--list']), 0);
    });
  });

  group('reports', () {
    final failing = _workspace(flows: const [
      Flow(id: 'f-a', name: 'Alpha', steps: [
        FlowStep(endpointId: 'login', assertions: [Assertion(field: 'response.status', expected: '201')]),
      ]),
    ]);

    test('--junit and --json write their files, creating the folder', () async {
      final junit = '${tmp.path}/out/dir/report.xml';
      final json = '${tmp.path}/report.json';

      final code = await run(['-w', await write(failing), '-e', 'qa', '--junit', junit, '--json', json]);

      expect(code, 1);
      expect(File(junit).readAsStringSync(), contains('<failure message="Assertion failed: expected response.status == &quot;201&quot;'));
      final decoded = jsonDecode(File(json).readAsStringSync()) as Map<String, dynamic>;
      expect(decoded['environment'], 'qa');
      expect(decoded['startedAt'], '2026-10-11T14:03:22.000Z');
      expect(decoded['summary']['flowsFailed'], 1);
    });

    test('a report that cannot be written exits 2 after running, and says which', () async {
      final blocker = File('${tmp.path}/blocker')..writeAsStringSync('a file, not a folder');

      final code = await run(['-w', await write(_workspace()), '-e', 'qa', '--junit', '${blocker.path}/report.xml']);

      expect(code, 2);
      expect(out.toString(), contains('2 flows: 2 passed'));
      expect(err.toString(), contains('cannot write'));
      expect(err.toString(), contains('report.xml'));
    });

    test('the other report is still written when one fails', () async {
      final blocker = File('${tmp.path}/blocker')..writeAsStringSync('x');
      final json = '${tmp.path}/ok.json';

      await run(['-w', await write(_workspace()), '-e', 'qa', '--junit', '${blocker.path}/r.xml', '--json', json]);

      expect(File(json).existsSync(), isTrue);
    });
  });

  group('a report path that would overwrite something else', () {
    test('--json on the workspace file itself is refused and the file is left alone', () async {
      final path = await write(_workspace());
      final before = File(path).readAsStringSync();
      final executor = FakeExecutor({});

      final code = await run(['-w', path, '-e', 'qa', '--json', path], executor: executor);

      expect(code, 2);
      expect(err.toString(), contains('error:'));
      expect(err.toString(), contains('--json'));
      expect(err.toString(), contains('workspace'));
      expect(File(path).readAsStringSync(), before);
      expect(executor.calls, isEmpty, reason: 'nothing runs when the paths clash');
    });

    test('--junit on the workspace file itself is refused too', () async {
      final path = await write(_workspace());
      final before = File(path).readAsStringSync();

      final code = await run(['-w', path, '-e', 'qa', '--junit', path]);

      expect(code, 2);
      expect(err.toString(), contains('--junit'));
      expect(File(path).readAsStringSync(), before);
    });

    test('the same file spelled differently is still the same file', () async {
      final path = await write(_workspace());
      final before = File(path).readAsStringSync();
      await Directory('${tmp.path}/sub').create();

      final code = await run(['-w', path, '-e', 'qa', '--json', '${tmp.path}/sub/../ws.workspace.json']);

      expect(code, 2);
      expect(File(path).readAsStringSync(), before);
    });

    test('a link to the workspace file is the workspace file', () async {
      final path = await write(_workspace());
      final before = File(path).readAsStringSync();
      final link = Link('${tmp.path}/report-link.json')..createSync(path);

      final code = await run(['-w', path, '-e', 'qa', '--json', link.path]);

      expect(code, 2);
      expect(File(path).readAsStringSync(), before);
    }, skip: Platform.isWindows ? 'creating links needs privileges on Windows' : false);

    test('--junit and --json to the same path would overwrite each other: refused', () async {
      final report = '${tmp.path}/report';
      final executor = FakeExecutor({});

      final code = await run(['-w', await write(_workspace()), '-e', 'qa', '--junit', report, '--json', report], executor: executor);

      expect(code, 2);
      expect(err.toString(), contains('same file'));
      expect(executor.calls, isEmpty);
      expect(File(report).existsSync(), isFalse);
    });

    test('different paths are fine, even in the same folder', () async {
      final code = await run(['-w', await write(_workspace()), '-e', 'qa', '--junit', '${tmp.path}/a.xml', '--json', '${tmp.path}/a.json']);

      expect(code, 0);
    });
  });

  group('secrets', () {
    const secret = 'sup3r-s3cret-key';
    const token = 'tok-abcdef123456';

    test('never appear in the output, the warnings or the reports', () async {
      final ws = _workspace(flows: const [
        Flow(id: 'f-a', name: 'Alpha', steps: [
          FlowStep(endpointId: 'login', extract: {'access_token': 'response.body.token'}),
          FlowStep(endpointId: 'items', assertions: [Assertion(field: 'response.body.echo', expected: 'something else')]),
        ]),
      ]);
      final executor = FakeExecutor({
        'login': (_) => const ExecutedResponse(status: 200, body: {'token': token}, requestUrl: 'https://qa.test/login?k=$secret'),
        'items': (v) => ExecutedResponse(status: 200, body: {'echo': '${v['api_key']}|$token'}, requestUrl: 'https://qa.test/items?k=${v['api_key']}'),
      });
      final junit = '${tmp.path}/r.xml';
      final json = '${tmp.path}/r.json';

      final code = await run(['-w', await write(ws), '-e', 'qa', '--var', 'api_key=$secret', '-v', '--junit', junit, '--json', json], executor: executor);

      expect(code, 1);
      final everything = [out.toString(), err.toString(), File(junit).readAsStringSync(), File(json).readAsStringSync()].join('\n');
      expect(everything, isNot(contains(secret)));
      expect(everything, isNot(contains(token)));
      expect(everything, contains('***'));
    });
  });
}
