import 'dart:convert';
import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late JsonStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('json_store_test_');
    store = JsonStore(directory: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('environments', () {
    test('round-trips a populated list through disk', () async {
      final environments = [
        const Environment(
          id: 'env-1',
          name: 'Development',
          variables: {'base_url': EnvironmentVariable(value: 'https://api.dev')},
        ),
      ];

      await store.writeEnvironments(environments);
      final result = await store.readEnvironments();

      expect(result, environments);
    });

    test('returns an empty list when no file exists yet', () async {
      expect(await store.readEnvironments(), isEmpty);
    });

    test('creates the storage directory if missing', () async {
      final missingDir = Directory('${tempDir.path}${Platform.pathSeparator}nested');
      final nestedStore = JsonStore(directory: missingDir);

      await nestedStore.writeEnvironments(const []);

      expect(await missingDir.exists(), isTrue);
    });

    test('a stray .tmp file from a simulated crash does not corrupt the real read', () async {
      final environments = [const Environment(id: 'env-1', name: 'Development')];
      await store.writeEnvironments(environments);

      // Simulate a crash after the temp file was written but before rename.
      final tmp = File('${tempDir.path}${Platform.pathSeparator}environments.json.tmp');
      await tmp.writeAsString('not valid json {{{');

      expect(await store.readEnvironments(), environments);
    });

    test('a hand-corrupted file is backed up and read returns an empty default', () async {
      final target = File('${tempDir.path}${Platform.pathSeparator}environments.json');
      await target.writeAsString('{ this is not valid json');

      final result = await store.readEnvironments();

      expect(result, isEmpty);
      final backups = await tempDir
          .list()
          .where((e) => e.path.contains('environments.json.corrupt-'))
          .toList();
      expect(backups, hasLength(1));
    });
  });

  group('active environment id', () {
    test('is null when no settings file exists yet', () async {
      expect(await store.readActiveEnvironmentId(), isNull);
    });

    test('round-trips through disk', () async {
      await store.writeActiveEnvironmentId('env-1');

      expect(await store.readActiveEnvironmentId(), 'env-1');
    });
  });

  group('collections', () {
    test('round-trips groups and endpoints through disk', () async {
      const groups = [Group(id: 'g-1', name: 'Authentication API')];
      const endpoints = [
        Endpoint(
          id: 'e-1',
          groupId: 'g-1',
          name: 'Login',
          method: 'POST',
          url: '{{base_url}}/login',
        ),
      ];

      await store.writeCollections(groups: groups, endpoints: endpoints);
      final result = await store.readCollections();

      expect(result.groups, groups);
      expect(result.endpoints, endpoints);
    });

    test('returns empty groups and endpoints when no file exists yet', () async {
      final result = await store.readCollections();

      expect(result.groups, isEmpty);
      expect(result.endpoints, isEmpty);
    });
  });

  group('flows', () {
    test('round-trips a flow with steps through disk', () async {
      const flows = [
        Flow(
          id: 'f-1',
          name: 'User Registration Flow',
          steps: [FlowStep(endpointId: 'e-1')],
        ),
      ];

      await store.writeFlows(flows);

      expect(await store.readFlows(), flows);
    });
  });

  test('writes are atomic: no .tmp file survives a successful write', () async {
    await store.writeEnvironments(const [Environment(id: 'env-1', name: 'Development')]);

    final tmp = File('${tempDir.path}${Platform.pathSeparator}environments.json.tmp');
    expect(await tmp.exists(), isFalse);

    final target = File('${tempDir.path}${Platform.pathSeparator}environments.json');
    expect(jsonDecode(await target.readAsString()), isA<List>());
  });
}
