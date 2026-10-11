import 'dart:convert';

import 'package:api_flow_studio/engine/import/import_registry.dart';
import 'package:api_flow_studio/engine/import/import_source.dart';
import 'package:api_flow_studio/engine/import/importer.dart';
import 'package:api_flow_studio/engine/import/postman/postman_environment_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const importer = PostmanEnvironmentImporter();

  bool matches(Object json) => importer.matches(ImportSource(jsonEncode(json)));

  Map<String, Object?> environment({
    String? name = 'Staging',
    List<Object?> values = const [],
    String scope = 'environment',
  }) =>
      {
        'name': ?name,
        'values': values,
        '_postman_variable_scope': scope,
      };

  group('matches', () {
    test('an environment and a globals file', () {
      expect(matches(environment()), isTrue);
      expect(matches(environment(scope: 'globals')), isTrue);
    });

    test('a file with values that look like variables, even without the scope key', () {
      expect(matches({'name': 'x', 'values': [{'key': 'a', 'value': '1'}]}), isTrue);
    });

    test('not a collection (it has info or item)', () {
      expect(matches({'info': {'name': 'x'}, 'item': [], 'values': []}), isFalse);
      expect(matches({'item': [], 'values': [], '_postman_variable_scope': 'environment'}), isFalse);
    });

    test('not values that are not variables', () {
      expect(matches({'values': [1, 2, 3]}), isFalse);
      expect(matches({'values': 'x'}), isFalse);
    });

    test('not an unrelated file, text, or nothing', () {
      expect(matches({'groups': [], 'endpoints': []}), isFalse);
      expect(matches({'openapi': '3.0.0'}), isFalse);
      expect(matches([1]), isFalse);
      expect(importer.matches(ImportSource('not json')), isFalse);
      expect(importer.matches(ImportSource('')), isFalse);
    });
  });

  group('parse', () {
    ImportSource source(Object json) => ImportSource(jsonEncode(json));

    test('is one environment with its variables, named as in the file', () {
      final result = importer.parse(source(environment(values: [
        {'key': 'base_url', 'value': 'https://staging.test', 'enabled': true, 'type': 'default'},
        {'key': 'count', 'value': 3},
      ])));

      expect(result.source, 'Postman environment');
      expect(result.groups, isEmpty);
      expect(result.endpoints, isEmpty);
      final env = result.environments.single;
      expect(env.name, 'Staging');
      expect(env.variables['base_url']!.value, 'https://staging.test');
      expect(env.variables['base_url']!.secret, isFalse);
      expect(env.variables['count']!.value, '3');
      expect(result.warnings, isEmpty);
    });

    test('a variable of type secret is a secret one', () {
      final env = importer.parse(source(environment(values: [
        {'key': 'api_key', 'value': 's3cret', 'type': 'secret'},
        {'key': 'empty_key', 'value': '', 'type': 'secret'},
      ]))).environments.single;

      expect(env.variables['api_key']!.secret, isTrue);
      expect(env.variables['api_key']!.value, 's3cret');
      expect(env.variables['empty_key']!.secret, isTrue);
    });

    test('a missing value is empty', () {
      final env = importer.parse(source(environment(values: [{'key': 'a'}, {'key': 'b', 'value': null}]))).environments.single;

      expect(env.variables['a']!.value, '');
      expect(env.variables['b']!.value, '');
    });

    test('a disabled entry is left out, and one warning names them', () {
      final result = importer.parse(source(environment(values: [
        {'key': 'on', 'value': '1'},
        {'key': 'off', 'value': '2', 'enabled': false},
        {'key': 'also_off', 'value': '3', 'enabled': false},
      ])));

      expect(result.environments.single.variables.keys, ['on']);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single.where, '');
      expect(result.warnings.single.message, 'disabled variables were left out: off, also_off');
    });

    test('entries without a key are skipped, and repeated keys keep the first, each with a warning', () {
      final result = importer.parse(source(environment(values: [
        {'value': 'no key'},
        {'key': '', 'value': 'empty key'},
        'not even a map',
        {'key': 'dup', 'value': 'first'},
        {'key': 'dup', 'value': 'second'},
      ])));

      expect(result.environments.single.variables['dup']!.value, 'first');
      expect(result.environments.single.variables, hasLength(1));
      final messages = result.warnings.map((w) => w.message);
      expect(messages, contains('3 entries without a variable name were skipped'));
      expect(messages, contains('variable "dup" is repeated; the first value was kept'));
    });

    test('names the engine cannot resolve are renamed, with one warning for the file', () {
      final result = importer.parse(source(environment(values: [
        {'key': 'base-url', 'value': 'https://x.test'},
        {'key': 'api.key', 'value': 'k'},
      ])));

      expect(result.environments.single.variables.keys, ['base_url', 'api_key']);
      final renamed = result.warnings.where((w) => w.message.startsWith('variable names changed'));
      expect(renamed, hasLength(1));
      expect(renamed.single.message, contains('base-url → base_url'));
      expect(renamed.single.message, contains('api.key → api_key'));
    });

    test('variables inside the values follow the same rules', () {
      final result = importer.parse(source(environment(values: [
        {'key': 'base', 'value': 'https://x.test'},
        {'key': 'full', 'value': '{{ base }}/{{api-version}}/{{\$guid}}/{{\$randomFirstName}}'},
      ])));

      expect(result.environments.single.variables['full']!.value, '{{base}}/{{api_version}}/{{\$uuid}}/{{\$randomFirstName}}');
      expect(result.warnings.map((w) => w.message), contains('unknown dynamic variable {{\$randomFirstName}} left as written'));
      final unknown = result.warnings.firstWhere((w) => w.message.startsWith('unknown dynamic'));
      expect(unknown.where, 'full');
    });

    test('a file without a name gets one by kind, and globals say so', () {
      expect(importer.parse(source(environment(name: null))).environments.single.name, 'Postman environment');
      expect(importer.parse(source(environment(name: null, scope: 'globals'))).environments.single.name, 'Postman globals');
      expect(importer.parse(source(environment(name: '   '))).environments.single.name, 'Postman environment');
    });

    test('the globals keep their own name and are reported as globals', () {
      final result = importer.parse(source(environment(name: 'Team globals', scope: 'globals')));

      expect(result.source, 'Postman globals');
      expect(result.environments.single.name, 'Team globals');
    });

    test('an environment without variables is still an environment', () {
      final result = importer.parse(source(environment()));

      expect(result.environments.single.variables, isEmpty);
    });
  });

  group('with the real registry', () {
    test('runImport picks it for an environment file and applies nothing else', () {
      final text = jsonEncode(environment(values: [
        {'key': 'a', 'value': '1'},
      ]));

      final result = runImport(text, importers, fileName: 'staging.postman_environment.json');

      expect(result.source, 'Postman environment');
      expect(result.environments, hasLength(1));
      expect(result.endpoints, isEmpty);
    });

    test('the app\'s own importer does not take it first', () {
      final text = jsonEncode(environment(values: [
        {'key': 'a', 'value': '1'},
      ]));

      expect(runImport(text, importers).source, isNot('API Flow Studio collections'));
    });

    test('the open dialog still offers json only', () {
      expect(supportedExtensions(importers), ['json']);
    });

    test('a ready-to-import message lists the Postman environment among the supported formats', () {
      expect(
        () => runImport('{"hello": 1}', importers),
        throwsA(isA<ImportException>().having((e) => e.message, 'message', contains('Postman environment'))),
      );
    });
  });
}
