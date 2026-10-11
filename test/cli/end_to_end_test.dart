import 'dart:convert';
import 'dart:io';

import 'package:api_flow_studio/cli/run_cli.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/workspace/workspace_file.dart';
import 'package:flutter_test/flutter_test.dart';

/// The runner against a real HTTP server on localhost, with the real dio-based
/// executor: nothing is faked between the command line and the socket.
void main() {
  const token = 'tok-9f8e7d6c5b4a';

  late HttpServer server;
  late Directory tmp;
  late StringBuffer out;
  late StringBuffer err;
  final received = <({String method, String path, Map<String, String> headers, String body})>[];

  setUp(() async {
    received.clear();
    out = StringBuffer();
    err = StringBuffer();
    tmp = await Directory.systemTemp.createTemp('cli_e2e_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decodeStream(request);
      received.add((
        method: request.method,
        path: request.uri.path,
        headers: {for (final name in ['authorization', 'content-type']) name: request.headers.value(name) ?? ''},
        body: body,
      ));
      final response = request.response..headers.contentType = ContentType.json;
      switch (request.uri.path) {
        case '/login':
          response.write(jsonEncode({'token': token}));
        case '/items':
          response.write(jsonEncode({
            'items': [
              {'name': 'Apple'},
            ],
          }));
        case '/users':
          response.statusCode = 201;
          response.write(jsonEncode({'id': 'u-1'}));
        case '/slow':
          await Future<void>.delayed(const Duration(seconds: 4));
          response.write('{}');
        default:
          response.statusCode = 404;
          response.write('{}');
      }
      await response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  String baseUrl() => 'http://localhost:${server.port}';

  Future<String> workspace(List<Flow> flows, {List<Endpoint> endpoints = const []}) async {
    final file = WorkspaceFile(
      name: 'e2e',
      environments: [
        Environment(id: 'e', name: 'local', variables: {'base_url': EnvironmentVariable(value: baseUrl())}),
      ],
      endpoints: [
        const Endpoint(id: 'login', groupId: 'g', name: 'Log in', method: 'POST', url: '{{base_url}}/login'),
        const Endpoint(
          id: 'items',
          groupId: 'g',
          name: 'List items',
          method: 'GET',
          url: '{{base_url}}/items',
          headers: [KeyValueEntry(key: 'Authorization', value: 'Bearer {{access_token}}')],
        ),
        const Endpoint(
          id: 'create',
          groupId: 'g',
          name: 'Create user',
          method: 'POST',
          url: '{{base_url}}/users',
          body: RequestBody.json('{"email":"{{\$randomEmail}}"}'),
        ),
        const Endpoint(id: 'slow', groupId: 'g', name: 'Slow', method: 'GET', url: '{{base_url}}/slow'),
        ...endpoints,
      ],
      flows: flows,
      exportedAt: DateTime.utc(2026),
    );
    final path = '${tmp.path}/e2e.workspace.json';
    await File(path).writeAsString(file.encode());
    return path;
  }

  Future<int> run(List<String> args) => runCli(args, out: out, err: err);

  const signup = Flow(id: 'f-signup', name: 'Signup', steps: [
    FlowStep(endpointId: 'login', extract: {'access_token': 'response.body.token'}, assertions: [
      Assertion(field: 'response.status', expected: '200'),
      Assertion(field: 'response.body.token', operator: AssertionOperator.exists),
    ]),
    FlowStep(endpointId: 'items', assertions: [
      Assertion(field: 'response.body.items.0.name', expected: 'Apple'),
      Assertion(field: 'response.elapsedMs', operator: AssertionOperator.lessThan, expected: '3000'),
    ]),
    FlowStep(endpointId: 'create', assertions: [Assertion(field: 'response.status', expected: '201')]),
  ]);

  test('a flow that chains steps over real HTTP passes: exit 0 and a JUnit report', () async {
    final path = await workspace([signup]);
    final junit = '${tmp.path}/report.xml';

    final code = await run(['-w', path, '--junit', junit]);

    expect(code, 0, reason: 'out: $out\nerr: $err');
    expect(out.toString(), contains('[PASS] 3. Create user'));
    expect(received.map((r) => '${r.method} ${r.path}'), ['POST /login', 'GET /items', 'POST /users']);
    // The value extracted from the first response reached the second request.
    expect(received[1].headers['authorization'], 'Bearer $token');
    final xml = File(junit).readAsStringSync();
    expect(xml, contains('<testsuite name="Signup" tests="3" failures="0" errors="0" skipped="0"'));
  });

  test('a token extracted from a response is masked even in the failure that quotes it', () async {
    final path = await workspace([
      const Flow(id: 'f', name: 'Leaky', steps: [
        FlowStep(
          endpointId: 'login',
          extract: {'access_token': 'response.body.token'},
          assertions: [Assertion(field: 'response.body.token', expected: 'something else')],
        ),
      ]),
    ]);
    final json = '${tmp.path}/r.json';

    final code = await run(['-w', path, '-v', '--json', json]);

    expect(code, 1);
    expect(out.toString(), contains('got "***"'));
    expect(out.toString() + err.toString() + File(json).readAsStringSync(), isNot(contains(token)));
  });

  test('a {{\$token}} is generated for the real request, anew on every run', () async {
    final path = await workspace([signup]);

    await run(['-w', path]);
    await run(['-w', path]);

    final emails = [
      for (final r in received.where((r) => r.path == '/users')) (jsonDecode(r.body) as Map)['email'] as String,
    ];
    expect(emails, hasLength(2));
    for (final email in emails) {
      expect(email, matches(RegExp(r'^test\.[a-z0-9]{8}@example\.com$')));
    }
    expect(emails[0], isNot(emails[1]));
  });

  test('an assertion that does not hold exits 1 and the later steps are skipped', () async {
    final path = await workspace([
      const Flow(id: 'f', name: 'Broken', steps: [
        FlowStep(endpointId: 'login', assertions: [Assertion(field: 'response.status', expected: '201')]),
        FlowStep(endpointId: 'items'),
      ]),
    ]);

    final code = await run(['-w', path]);

    expect(code, 1);
    expect(out.toString(), contains('got "200"'));
    expect(out.toString(), contains('[SKIP] 2. List items'));
    expect(received.map((r) => r.path), ['/login']);
  });

  test('--timeout cuts a slow request short and the run fails without hanging', () async {
    final path = await workspace([
      const Flow(id: 'f', name: 'Slow', steps: [FlowStep(endpointId: 'slow'), FlowStep(endpointId: 'items')]),
    ]);
    final watch = Stopwatch()..start();

    final code = await run(['-w', path, '--timeout', '1']);

    expect(code, 1);
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)), reason: 'the server waits 4 s; the timeout is 1 s');
    expect(out.toString(), contains('[FAIL] 1. Slow'));
    expect(out.toString(), contains('[SKIP] 2. List items'));
  });

  test('a server that is not there is a failed step, not a crash', () async {
    final path = await workspace([signup]);
    await server.close(force: true);

    final code = await run(['-w', path]);

    expect(code, 1);
    expect(out.toString(), contains('[FAIL] 1. Log in'));
    expect(err.toString(), isNot(contains('error:')));
  });

  test('a url that still has an undefined {{variable}} fails the step with a plain explanation', () async {
    final path = await workspace([
      const Flow(id: 'f', name: 'Typo', steps: [FlowStep(endpointId: 'typo')]),
    ], endpoints: [
      const Endpoint(id: 'typo', groupId: 'g', name: 'Typo', method: 'GET', url: '{{base_ulr}}/items'),
    ]);

    final code = await run(['-w', path]);

    expect(code, 1);
    expect(out.toString(), contains('Unresolved variable in the URL: {{base_ulr}}'));
    expect(out.toString(), isNot(contains('DioException')));
    expect(received, isEmpty);
  });
}
