import 'dart:convert';
import 'dart:io';

import 'package:api_flow_studio/engine/import/app_collections_importer.dart';
import 'package:api_flow_studio/engine/import/import_registry.dart';
import 'package:api_flow_studio/engine/import/import_source.dart';
import 'package:api_flow_studio/engine/import/importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const importer = AppCollectionsImporter();

  bool matches(Object json) => importer.matches(ImportSource(jsonEncode(json)));

  group('matches', () {
    test('a file with groups and endpoints', () {
      expect(matches({'groups': [], 'endpoints': []}), isTrue);
    });

    test('either list is enough', () {
      expect(matches({'groups': []}), isTrue);
      expect(matches({'endpoints': []}), isTrue);
    });

    test('not when they are not lists', () {
      expect(matches({'groups': {}, 'endpoints': 3}), isFalse);
      expect(matches({'groups': 'x'}), isFalse);
    });

    test('not an empty object, a list, or a scalar', () {
      expect(matches(<String, Object>{}), isFalse);
      expect(matches([1, 2]), isFalse);
      expect(matches('text'), isFalse);
    });

    test('not text that is not JSON', () {
      expect(importer.matches(ImportSource('groups: []')), isFalse);
      expect(importer.matches(ImportSource('')), isFalse);
    });

    test('not the files that other formats are made of', () {
      for (final other in [
        {'info': {}, 'item': [], 'groups': [], 'endpoints': []},
        {'openapi': '3.0.0', 'endpoints': []},
        {'swagger': '2.0', 'groups': []},
        {'values': [], 'groups': []},
      ]) {
        expect(matches(other), isFalse, reason: '$other');
      }
    });
  });

  group('parse', () {
    ImportSource source(Object json) => ImportSource(jsonEncode(json));

    Map<String, Object?> group(String id, String name, {String? parent}) =>
        {'id': id, 'name': name, 'parentGroupId': parent, 'order': 0};

    Map<String, Object?> endpoint(String id, String groupId, String name) => {
          'id': id,
          'groupId': groupId,
          'name': name,
          'method': 'GET',
          'url': 'https://x.test/$id',
        };

    test('reads folders and requests with the app\'s own models', () {
      final result = importer.parse(source({
        'groups': [group('g1', 'Auth'), group('g2', 'Sessions', parent: 'g1')],
        'endpoints': [endpoint('e1', 'g1', 'Login'), endpoint('e2', 'g2', 'Refresh')],
      }));

      expect(result.source, 'API Flow Studio collections');
      expect(result.groups.map((g) => g.name), ['Auth', 'Sessions']);
      expect(result.groups[1].parentGroupId, 'g1');
      expect(result.endpoints.map((e) => e.name), ['Login', 'Refresh']);
      expect(result.environments, isEmpty);
      expect(result.warnings, isEmpty);
    });

    test('a missing list is an empty one', () {
      final result = importer.parse(source({'groups': [group('g', 'Only folders')]}));

      expect(result.groups, hasLength(1));
      expect(result.endpoints, isEmpty);
    });

    test('a request whose folder is not in the file is left out, with a warning naming it', () {
      final result = importer.parse(source({
        'groups': [group('g1', 'Auth')],
        'endpoints': [endpoint('e1', 'g1', 'Login'), endpoint('e2', 'gone', 'Orphan')],
      }));

      expect(result.endpoints.map((e) => e.name), ['Login']);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single.where, 'Orphan');
      expect(result.warnings.single.message, 'its folder is not in the file; skipped');
    });

    test('a folder whose parent is not in the file is kept as a top-level folder, with a warning', () {
      final result = importer.parse(source({
        'groups': [group('g1', 'Lost', parent: 'nope')],
        'endpoints': [endpoint('e1', 'g1', 'Login')],
      }));

      expect(result.groups.single.parentGroupId, isNull);
      expect(result.endpoints, hasLength(1));
      expect(result.warnings.single.where, 'Lost');
      expect(result.warnings.single.message, 'its parent folder is not in the file; imported at the top level');
    });

    test('repeated ids do not break it', () {
      final result = importer.parse(source({
        'groups': [group('g', 'One'), group('g', 'Two')],
        'endpoints': [endpoint('e', 'g', 'A'), endpoint('e', 'g', 'B')],
      }));

      expect(result.groups, hasLength(2));
      expect(result.endpoints, hasLength(2));
    });

    test('a Form Data request keeps its fields (the paths are cleared when it is applied)', () {
      final result = importer.parse(source({
        'groups': [group('g', 'Uploads')],
        'endpoints': [
          {
            ...endpoint('e', 'g', 'Upload'),
            'body': {
              'runtimeType': 'multipart',
              'fields': [
                {'name': 'f', 'kind': 'file', 'value': '/x'},
              ],
            },
          },
        ],
      }));

      expect(result.endpoints.single.body.maybeMap(multipart: (b) => b.fields.length, orElse: () => 0), 1);
    });
  });

  group('with the real registry', () {
    test('imports the sample-endpoints.json that ships with the app, with no warnings', () {
      final text = File('sample-endpoints.json').readAsStringSync();
      final decoded = jsonDecode(text) as Map<String, dynamic>;

      final result = runImport(text, importers, fileName: 'sample-endpoints.json');

      expect(result.groups, hasLength((decoded['groups'] as List).length));
      expect(result.endpoints, hasLength((decoded['endpoints'] as List).length));
      expect(result.warnings, isEmpty);
    });

    test('refuses a workspace file with the pointer', () {
      final workspace = jsonEncode({'format': 'api-flow-studio-workspace', 'version': 3, 'project': {'name': 'x'}, 'groups': [], 'endpoints': []});

      expect(() => runImport(workspace, importers), throwsA(isA<ImportException>().having((e) => e.message, 'message', startsWith('This is a workspace file'))));
    });

    test('refuses a file that is empty of requests', () {
      expect(
        () => runImport('{"groups": [], "endpoints": []}', importers),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', 'Nothing to import: API Flow Studio collections had no requests.')),
      );
    });

    test('refuses a file of a shape nobody here reads, listing what is supported', () {
      expect(
        () => runImport('{"hello": 1}', importers),
        throwsA(isA<ImportException>().having(
          (e) => e.message,
          'message',
          allOf(startsWith('That file is not a format I can import. Supported: '), contains('API Flow Studio collections')),
        )),
      );
    });

    test('a damaged element is reported as a damaged file, not a crash', () {
      expect(
        () => runImport('{"groups": [], "endpoints": [{"id": 1}]}', importers),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', 'That file looks like API Flow Studio collections but is damaged or incomplete.')),
      );
    });

    test('offers the json extension to the open dialog', () {
      expect(supportedExtensions(importers), ['json']);
    });
  });
}
