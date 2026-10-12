import 'dart:io';

import 'package:api_flow_studio/engine/flows/flows_file.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Endpoint endpoint(String id, String groupId, {String method = 'GET', String? url, AuthConfig? auth}) => Endpoint(
      id: id,
      groupId: groupId,
      name: id,
      method: method,
      url: url ?? '{{BASE}}/$id',
      authConfig: auth ?? const AuthConfig.none(),
    );

Matcher problem(FlowsFileProblem expected) =>
    throwsA(isA<FlowsFileException>().having((e) => e.problem, 'problem', expected));

void main() {
  final groups = [
    const Group(id: 'g-root', name: 'Auth'),
    const Group(id: 'g-child', name: 'Login', parentGroupId: 'g-root'),
    const Group(id: 'g-other', name: 'Unused'),
  ];
  final endpoints = [
    endpoint('login', 'g-child', method: 'POST', auth: const AuthConfig.bearer(token: 'secret-literal')),
    endpoint('me', 'g-root', auth: const AuthConfig.bearer(token: '{{access_token}}')),
    endpoint('other', 'g-other'),
  ];
  const flowA = Flow(id: 'a', name: 'Login flow', steps: [FlowStep(endpointId: 'login'), FlowStep(endpointId: 'me')]);
  const flowB = Flow(id: 'b', name: 'Other', steps: [FlowStep(endpointId: 'other')]);

  group('buildFlowsFile', () {
    test('carries only the requests and folders the chosen flows use, without literal credentials', () {
      final file = buildFlowsFile([flowA], groups: groups, endpoints: endpoints, now: () => DateTime.utc(2026));

      expect(file.endpoints.map((e) => e.id), ['login', 'me']);
      expect(file.groups.map((g) => g.id), unorderedEquals(['g-root', 'g-child']));
      expect((file.endpoints.first.authConfig as AuthConfigBearer).token, isEmpty);
      expect((file.endpoints.last.authConfig as AuthConfigBearer).token, '{{access_token}}');
    });

    test('survives encode and parse', () {
      final file = buildFlowsFile([flowA, flowB], groups: groups, endpoints: endpoints);
      final parsed = FlowsFile.parse(file.encode());

      expect(parsed.flows.map((f) => f.name), ['Login flow', 'Other']);
      expect(parsed.endpoints, hasLength(3));
    });
  });

  group('FlowsFile.parse', () {
    test('rejects what is not a flows file', () {
      expect(() => FlowsFile.parse('nope'), problem(FlowsFileProblem.notJson));
      expect(() => FlowsFile.parse('{"format":"api-flow-studio-workspace","version":1}'), problem(FlowsFileProblem.notAFlowsFile));
      expect(() => FlowsFile.parse('{"format":"$flowsFileFormat","version":99}'), problem(FlowsFileProblem.newerVersion));
      expect(() => FlowsFile.parse('{"format":"$flowsFileFormat","version":1,"flows":[{"x":1}]}'), problem(FlowsFileProblem.invalid));
    });
  });

  group('planFlowsImport', () {
    final file = buildFlowsFile([flowA, flowB], groups: groups, endpoints: endpoints);

    test('into an empty project adds the folders, requests and flows with new ids', () {
      final plan = planFlowsImport(file, selected: {'a', 'b'}, existingGroups: const [], existingEndpoints: const [], existingFlows: const []);

      expect(plan.flows.map((f) => f.name), ['Login flow', 'Other']);
      expect(plan.newEndpoints, hasLength(3));
      expect(plan.newGroups.map((g) => g.name), unorderedEquals(['Auth', 'Login', 'Unused']));
      final ids = {for (final e in plan.newEndpoints) e.url: e.id};
      expect(plan.flows.first.steps.map((s) => s.endpointId), [ids['{{BASE}}/login'], ids['{{BASE}}/me']]);
      final login = plan.newGroups.firstWhere((g) => g.name == 'Login');
      expect(login.parentGroupId, plan.newGroups.firstWhere((g) => g.name == 'Auth').id);
      expect(plan.newEndpoints.every((e) => plan.newGroups.any((g) => g.id == e.groupId)), isTrue);
    });

    test('only the selected flows come in', () {
      final plan = planFlowsImport(file, selected: {'b'}, existingGroups: const [], existingEndpoints: const [], existingFlows: const []);

      expect(plan.flows.map((f) => f.name), ['Other']);
      expect(plan.newEndpoints.map((e) => e.name), ['other']);
    });

    test('reuses a request the project has (same method and URL) and the folder with the same name', () {
      final mine = endpoint('mine', 'm-auth', method: 'POST', url: '{{BASE}}/login');
      final plan = planFlowsImport(
        file,
        selected: {'a'},
        existingGroups: const [Group(id: 'm-auth', name: 'auth')],
        existingEndpoints: [mine],
        existingFlows: const [],
      );

      expect(plan.reusedEndpoints, 1);
      expect(plan.flows.single.steps.first.endpointId, 'mine');
      expect(plan.newEndpoints.map((e) => e.name), ['me']);
      expect(plan.newGroups, isEmpty);
      expect(plan.newEndpoints.single.groupId, 'm-auth');
    });

    test('numbers a flow name that is taken', () {
      final plan = planFlowsImport(
        file,
        selected: {'a'},
        existingGroups: const [],
        existingEndpoints: const [],
        existingFlows: const [Flow(id: 'x', name: 'Login flow')],
      );

      expect(plan.flows.single.name, 'Login flow (2)');
    });

    test('a step whose request is not in the file is counted and kept', () {
      final broken = FlowsFile(
        flows: const [Flow(id: 'z', name: 'Z', steps: [FlowStep(endpointId: 'gone')])],
        exportedAt: DateTime.utc(2026),
      );
      final plan = planFlowsImport(broken, selected: {'z'}, existingGroups: const [], existingEndpoints: const [], existingFlows: const []);

      expect(plan.missingSteps, 1);
      expect(plan.flows.single.steps.single.endpointId, 'gone');
    });

    test('a request without its folder goes to an "Imported flows" folder', () {
      final orphan = FlowsFile(
        flows: const [Flow(id: 'o', name: 'O', steps: [FlowStep(endpointId: 'e')])],
        endpoints: [endpoint('e', 'nowhere')],
        exportedAt: DateTime.utc(2026),
      );
      final plan = planFlowsImport(orphan, selected: {'o'}, existingGroups: const [], existingEndpoints: const [], existingFlows: const []);

      expect(plan.newGroups.single.name, 'Imported flows');
      expect(plan.newEndpoints.single.groupId, plan.newGroups.single.id);
    });
  });

  test('sample-flows.json is a valid flows file whose steps all point at requests it carries', () {
    final file = FlowsFile.parse(File('sample-flows.json').readAsStringSync());

    expect(file.flows.length, greaterThanOrEqualTo(3));
    final ids = {for (final e in file.endpoints) e.id};
    for (final flow in file.flows) {
      expect(flow.steps, isNotEmpty);
      expect(flow.steps.every((s) => ids.contains(s.endpointId)), isTrue, reason: flow.name);
    }
    final groupIds = {for (final g in file.groups) g.id};
    expect(file.endpoints.every((e) => groupIds.contains(e.groupId)), isTrue);
  });
}
