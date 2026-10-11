import 'dart:convert';

import 'package:api_flow_studio/engine/import/import_result.dart';
import 'package:api_flow_studio/engine/import/import_source.dart';
import 'package:api_flow_studio/engine/import/importer.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// An importer that claims a file when its text contains [marker].
class FakeImporter implements Importer {
  FakeImporter(this.formatName, this.marker, {this.result, this.error, this.matchesThrows = false});

  @override
  final String formatName;
  final String marker;
  final ImportResult? result;
  final Object? error;
  final bool matchesThrows;
  int parsed = 0;

  @override
  List<String> get extensions => const ['json'];

  @override
  bool matches(ImportSource source) {
    if (matchesThrows) throw StateError('boom');
    return source.text.contains(marker);
  }

  @override
  ImportResult parse(ImportSource source) {
    parsed++;
    if (error != null) throw error!;
    return result ?? ImportResult(source: formatName, groups: const [Group(id: 'g', name: 'G')], endpoints: [_endpoint]);
  }
}

const _endpoint = Endpoint(id: 'e', groupId: 'g', name: 'n', method: 'GET', url: '/');

void main() {
  group('runImport', () {
    test('uses the first importer that recognises the file, in order', () {
      final first = FakeImporter('First', 'x');
      final second = FakeImporter('Second', 'x');

      final result = runImport('x', [first, second]);

      expect(result.source, 'First');
      expect(first.parsed, 1);
      expect(second.parsed, 0);
    });

    test('skips an importer that does not match', () {
      final result = runImport('only-b', [FakeImporter('A', 'only-a'), FakeImporter('B', 'only-b')]);

      expect(result.source, 'B');
    });

    test('an importer whose check throws counts as not matching', () {
      final result = runImport('x', [FakeImporter('Broken', 'x', matchesThrows: true), FakeImporter('Fine', 'x')]);

      expect(result.source, 'Fine');
    });

    test('says which formats it supports when none recognises the file', () {
      expect(
        () => runImport('{"hello": 1}', [FakeImporter('Alpha', 'a'), FakeImporter('Beta', 'b')]),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', 'That file is not a format I can import. Supported: Alpha, Beta.')),
      );
    });

    test('says "not valid JSON" for a .json file that is not JSON and that nobody recognises', () {
      expect(
        () => runImport('{"a":', [FakeImporter('Alpha', 'zzz')], fileName: 'Broken.JSON'),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', 'That file is not valid JSON.')),
      );
    });

    test('a file that is not JSON and has another name gets the format message', () {
      expect(
        () => runImport('plain text', [FakeImporter('Alpha', 'zzz')], fileName: 'notes.txt'),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', startsWith('That file is not a format'))),
      );
    });

    test('passes the importer\'s own message through', () {
      expect(
        () => runImport('x', [FakeImporter('A', 'x', error: const ImportException('Version 9 is not supported.'))]),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', 'Version 9 is not supported.')),
      );
    });

    test('an importer that fails any other way is reported as a damaged file of its format', () {
      expect(
        () => runImport('x', [FakeImporter('Alpha', 'x', error: StateError('internal'))]),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', 'That file looks like Alpha but is damaged or incomplete.')),
      );
    });

    test('an importer that found nothing to import is reported', () {
      final empty = FakeImporter('Alpha', 'x', result: const ImportResult(source: 'Alpha'));

      expect(
        () => runImport('x', [empty]),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', 'Nothing to import: Alpha had no requests.')),
      );
    });

    test('a result with only environments is something to import', () {
      final onlyEnvironments = FakeImporter('Env', 'x', result: const ImportResult(source: 'Env', environments: [Environment(id: 'e', name: 'Dev')]));

      expect(runImport('x', [onlyEnvironments]).environments, hasLength(1));
    });

    test('a workspace file gets a pointer to the right command, even if an importer would take it', () {
      final text = jsonEncode({'format': 'api-flow-studio-workspace', 'version': 3, 'project': {'name': 'x'}});

      expect(
        () => runImport(text, [FakeImporter('Greedy', 'api-flow-studio')]),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', 'This is a workspace file. Use Project ▸ Import workspace… to open it as a new project.')),
      );
    });

    test('hands the importer the file name and the text', () {
      late ImportSource seen;
      final importer = _Recording((s) => seen = s);

      runImport('{"k": 1}', [importer], fileName: 'a.json');

      expect(seen.fileName, 'a.json');
      expect(seen.text, '{"k": 1}');
      expect(seen.json, {'k': 1});
    });

    test('with no importers there is nothing it can read', () {
      expect(() => runImport('{}', const []), throwsA(isA<ImportException>()));
    });
  });

  group('supportedExtensions', () {
    test('is every extension the importers declare, once', () {
      final a = FakeImporter('A', 'a');
      final b = _Recording((_) {}, extensions: const ['json', 'yaml', 'yml']);

      expect(supportedExtensions([a, b]), ['json', 'yaml', 'yml']);
    });
  });
}

class _Recording implements Importer {
  _Recording(this.onParse, {this.extensions = const ['json']});

  final void Function(ImportSource) onParse;

  @override
  final List<String> extensions;

  @override
  String get formatName => 'Recording';

  @override
  bool matches(ImportSource source) => true;

  @override
  ImportResult parse(ImportSource source) {
    onParse(source);
    return const ImportResult(source: 'Recording', groups: [Group(id: 'g', name: 'G')], endpoints: [_endpoint]);
  }
}
