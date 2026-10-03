import 'dart:convert';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/projects/project.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:api_flow_studio/engine/workspace/export_workspace.dart';
import 'package:api_flow_studio/engine/workspace/workspace_file.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final project = Project(id: 'p1', name: 'commodo', colorIndex: 3, createdAt: DateTime.utc(2026, 1, 1));
  final exportedAt = DateTime.utc(2026, 10, 3, 10);

  Future<JsonStore> seededStore() async {
    final store = JsonStore.inMemory();
    await store.writeEnvironments([
      const Environment(id: 'dev', name: 'Dev', variables: {
        'base_url': EnvironmentVariable(value: 'https://dev.test'),
        'api_key': EnvironmentVariable(value: 'S3CR3T-KEY', secret: true),
      }),
      const Environment(id: 'prod', name: 'Prod', variables: {
        'base_url': EnvironmentVariable(value: 'https://prod.test'),
        'api_key': EnvironmentVariable(value: 'PROD-S3CR3T', secret: true),
      }),
    ]);
    await store.writeActiveEnvironmentId('prod');
    await store.writeCollections(
      groups: const [Group(id: 'g1', name: 'Auth')],
      endpoints: const [
        Endpoint(id: 'e1', groupId: 'g1', name: 'Login', method: 'POST', url: '{{base_url}}/login'),
        Endpoint(
          id: 'e2',
          groupId: 'g1',
          name: 'Literal bearer',
          method: 'GET',
          url: '{{base_url}}/me',
          authConfig: AuthConfig.bearer(token: 'LITERAL-TOKEN'),
        ),
        Endpoint(
          id: 'e3',
          groupId: 'g1',
          name: 'Bearer by variable',
          method: 'GET',
          url: '{{base_url}}/me',
          authConfig: AuthConfig.bearer(token: '{{api_key}}'),
        ),
        Endpoint(
          id: 'e4',
          groupId: 'g1',
          name: 'Basic',
          method: 'GET',
          url: '{{base_url}}/basic',
          authConfig: AuthConfig.basic(username: 'ana', password: 'LITERAL-PASSWORD'),
        ),
      ],
    );
    await store.writeFlows([
      const Flow(id: 'f1', name: 'Signup', steps: [FlowStep(endpointId: 'e1'), FlowStep(endpointId: 'e2')]),
    ]);
    await store.writeHostNotes({'base_url': 'Main API'});
    await store.appendHistoryEntry(
      'e1',
      HistoryEntry(
        id: 'h1',
        endpointId: 'e1',
        timestamp: DateTime.utc(2026, 1, 1),
        status: 200,
        body: '{"accessToken":"HISTORY-TOKEN"}',
      ),
    );
    return store;
  }

  group('exporting a project', () {
    test('carries the project name and color and the format marks', () async {
      final file = await exportWorkspace(await seededStore(), project, now: () => exportedAt);

      final json = file.toJson();
      expect(json['format'], 'api-flow-studio-workspace');
      expect(json['version'], 1);
      expect(json['exportedAt'], exportedAt.toIso8601String());
      expect(json['project'], {'name': 'commodo', 'colorIndex': 3});
    });

    test('carries environments, collections, flows and host notes', () async {
      final file = await exportWorkspace(await seededStore(), project, now: () => exportedAt);

      expect(file.environments.map((e) => e.name), ['Dev', 'Prod']);
      expect(file.groups.single.name, 'Auth');
      expect(file.endpoints.map((e) => e.id), ['e1', 'e2', 'e3', 'e4']);
      expect(file.flows.single.steps.map((s) => s.endpointId), ['e1', 'e2']);
      expect(file.hostNotes, {'base_url': 'Main API'});
    });

    test('secret variables keep their name and flag but lose their value; the others are untouched', () async {
      final file = await exportWorkspace(await seededStore(), project, now: () => exportedAt);

      for (final env in file.environments) {
        expect(env.variables['api_key']!.secret, isTrue);
        expect(env.variables['api_key']!.value, isEmpty);
        expect(env.variables['base_url']!.value, startsWith('https://'));
      }
    });

    test('literal credentials in a request are blanked; references to variables are kept', () async {
      final file = await exportWorkspace(await seededStore(), project, now: () => exportedAt);
      final byId = {for (final e in file.endpoints) e.id: e};

      expect((byId['e2']!.authConfig as AuthConfigBearer).token, isEmpty);
      expect((byId['e3']!.authConfig as AuthConfigBearer).token, '{{api_key}}');
      final basic = byId['e4']!.authConfig as AuthConfigBasic;
      expect(basic.username, 'ana');
      expect(basic.password, isEmpty);
      expect(byId['e1']!.authConfig, const AuthConfig.none());
    });

    test('the file text holds no secret, no token and no history', () async {
      final file = await exportWorkspace(await seededStore(), project, now: () => exportedAt);

      final text = file.encode();

      for (final secret in ['S3CR3T-KEY', 'PROD-S3CR3T', 'LITERAL-TOKEN', 'LITERAL-PASSWORD', 'HISTORY-TOKEN']) {
        expect(text, isNot(contains(secret)), reason: secret);
      }
      expect(text, isNot(contains('activeEnvironmentId')));
      expect(jsonDecode(text), isNot(contains('history')));
    });

    test('an empty project exports an empty, valid file', () async {
      final file = await exportWorkspace(JsonStore.inMemory(), project, now: () => exportedAt);

      expect(file.environments, isEmpty);
      expect(file.endpoints, isEmpty);
      expect(WorkspaceFile.parse(file.encode()).name, 'commodo');
    });

    test('counts what the person importing has to fill in', () async {
      final file = await exportWorkspace(await seededStore(), project, now: () => exportedAt);

      // api_key in two environments, the literal bearer token and the basic password.
      expect(file.secretsToFill, 4);
    });
  });

  group('reading a file back', () {
    test('what was exported is read back identically', () async {
      final exported = await exportWorkspace(await seededStore(), project, now: () => exportedAt);

      final read = WorkspaceFile.parse(exported.encode());

      expect(read.name, exported.name);
      expect(read.colorIndex, 3);
      expect(read.environments, exported.environments);
      expect(read.groups, exported.groups);
      expect(read.endpoints, exported.endpoints);
      expect(read.flows, exported.flows);
      expect(read.hostNotes, exported.hostNotes);
      expect(read.exportedAt, exportedAt);
    });

    test('unknown extra fields are ignored and missing sections are empty', () {
      final read = WorkspaceFile.parse(jsonEncode({
        'format': 'api-flow-studio-workspace',
        'version': 1,
        'project': {'name': 'minimal'},
        'somethingNew': true,
      }));

      expect(read.name, 'minimal');
      expect(read.colorIndex, 0);
      expect(read.environments, isEmpty);
      expect(read.hostNotes, isEmpty);
    });

    void rejects(String text, WorkspaceFileProblem problem) {
      expect(
        () => WorkspaceFile.parse(text),
        throwsA(isA<WorkspaceFileException>().having((e) => e.problem, 'problem', problem)),
      );
    }

    test('text that is not JSON is rejected', () => rejects('this is not json', WorkspaceFileProblem.notJson));

    test('JSON that is not an object is rejected', () => rejects('[1, 2, 3]', WorkspaceFileProblem.notAWorkspace));

    test('a file of another kind is rejected', () {
      rejects(jsonEncode({'groups': [], 'endpoints': []}), WorkspaceFileProblem.notAWorkspace);
      rejects(jsonEncode({'format': 'something-else', 'version': 1}), WorkspaceFileProblem.notAWorkspace);
    });

    test('a newer version of the format is rejected, saying so', () {
      expect(
        () => WorkspaceFile.parse(jsonEncode({
          'format': 'api-flow-studio-workspace',
          'version': 2,
          'project': {'name': 'x'},
        })),
        throwsA(isA<WorkspaceFileException>()
            .having((e) => e.problem, 'problem', WorkspaceFileProblem.newerVersion)
            .having((e) => e.message, 'message', contains('newer'))),
      );
    });

    test('a missing or wrong version, or a missing project name, is rejected', () {
      const format = 'api-flow-studio-workspace';
      rejects(jsonEncode({'format': format, 'project': {'name': 'x'}}), WorkspaceFileProblem.invalid);
      rejects(jsonEncode({'format': format, 'version': 'one', 'project': {'name': 'x'}}), WorkspaceFileProblem.invalid);
      rejects(jsonEncode({'format': format, 'version': 0, 'project': {'name': 'x'}}), WorkspaceFileProblem.invalid);
      rejects(jsonEncode({'format': format, 'version': 1}), WorkspaceFileProblem.invalid);
      rejects(jsonEncode({'format': format, 'version': 1, 'project': {'name': '  '}}), WorkspaceFileProblem.invalid);
    });

    test('a section with the wrong shape is rejected', () {
      rejects(
        jsonEncode({
          'format': 'api-flow-studio-workspace',
          'version': 1,
          'project': {'name': 'x'},
          'environments': 'not a list',
        }),
        WorkspaceFileProblem.invalid,
      );
      rejects(
        jsonEncode({
          'format': 'api-flow-studio-workspace',
          'version': 1,
          'project': {'name': 'x'},
          'collections': {
            'groups': [],
            'endpoints': [
              {'id': 'e1'},
            ],
          },
        }),
        WorkspaceFileProblem.invalid,
      );
    });

    test('a file over the size limit is rejected without being read', () {
      rejects('x' * (maxWorkspaceFileChars + 1), WorkspaceFileProblem.tooLarge);
    });

    test('every problem has a message a person can read', () {
      for (final problem in WorkspaceFileProblem.values) {
        expect(WorkspaceFileException(problem).message, isNotEmpty);
      }
    });
  });

  group('the suggested file name', () {
    test('is the project name with the workspace extension', () {
      expect(workspaceFileName('commodo'), 'commodo.workspace.json');
    });

    test('replaces what a file name cannot hold', () {
      expect(workspaceFileName('Mi proyecto / v2: "beta"'), 'Mi_proyecto_v2_beta.workspace.json');
    });

    test('falls back to a plain name when nothing is left', () {
      expect(workspaceFileName('???'), 'workspace.workspace.json');
    });
  });
}
