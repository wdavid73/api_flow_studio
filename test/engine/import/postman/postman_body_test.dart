import 'dart:convert';

import 'package:api_flow_studio/engine/import/import_result.dart';
import 'package:api_flow_studio/engine/import/postman/postman_request.dart';
import 'package:api_flow_studio/engine/import/postman/postman_variables.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late VariableTranslator translator;
  late List<ImportWarning> warnings;

  setUp(() {
    translator = VariableTranslator();
    warnings = [];
  });

  Endpoint build(Object? body, {List<Map<String, Object?>> headers = const [], String path = 'Folder / Upload'}) => requestToEndpoint(
        item: {
          'name': 'Request',
          'request': {'method': 'POST', 'url': 'https://x.test/a', 'header': headers, 'body': body},
        },
        id: 'e',
        groupId: 'g',
        path: path,
        translator: translator,
        warnings: warnings,
      );

  List<MultipartField> multipart(Endpoint e) =>
      e.body.maybeMap(multipart: (b) => b.fields, orElse: () => throw StateError('body is ${e.body}'));

  String raw(Endpoint e) => e.body.maybeMap(json: (b) => b.raw, orElse: () => throw StateError('body is ${e.body}'));

  Map<String, Object?> rawBody(String text, {String? language}) => {
        'mode': 'raw',
        'raw': text,
        if (language != null) 'options': {'raw': {'language': language}},
      };

  group('no body', () {
    test('a missing body, a null mode and an empty raw are all no body', () {
      expect(build(null).body, const RequestBody.none());
      expect(build({'mode': null}).body, const RequestBody.none());
      expect(build({'mode': 'raw', 'raw': '   '}).body, const RequestBody.none());
      expect(build('not a map').body, const RequestBody.none());
      expect(warnings, isEmpty);
    });

    test('a disabled body is left out, with a warning', () {
      final endpoint = build({'mode': 'raw', 'raw': '{"a":1}', 'disabled': true});

      expect(endpoint.body, const RequestBody.none());
      expect(warnings.single.where, 'Folder / Upload');
      expect(warnings.single.message, 'the body is disabled in Postman; left empty');
    });

    test('a binary (file) body is left out, with a warning', () {
      final endpoint = build({'mode': 'file', 'file': {'src': '/Users/someone/data.bin'}});

      expect(endpoint.body, const RequestBody.none());
      expect(warnings.single.message, 'binary (file) body is not supported; the body was left empty');
      expect(endpoint.toJson().toString(), isNot(contains('/Users/someone')));
    });

    test('a mode nobody knows is left out, with a warning that names it', () {
      expect(build({'mode': 'hologram'}).body, const RequestBody.none());
      expect(warnings.single.message, 'body mode "hologram" is not supported; the body was left empty');
    });
  });

  group('raw', () {
    test('JSON is a JSON body, and brings no Content-Type of its own', () {
      final endpoint = build(rawBody('{"a": 1}', language: 'json'));

      expect(endpoint.body, const RequestBody.json('{"a": 1}'));
      expect(endpoint.headers, isEmpty);
      expect(warnings, isEmpty);
    });

    test('text that is JSON with no language, or with "text", is JSON too', () {
      expect(build(rawBody('{"a": [1, 2]}')).body, const RequestBody.json('{"a": [1, 2]}'));
      expect(build(rawBody('[1, 2]', language: 'text')).body, const RequestBody.json('[1, 2]'));
      expect(warnings, isEmpty);
    });

    test('a body with variables where JSON expects values still counts as JSON', () {
      final endpoint = build(rawBody('{"id": {{user_id}}, "name": "{{name}}"}'));

      expect(endpoint.body, const RequestBody.json('{"id": {{user_id}}, "name": "{{name}}"}'));
      expect(endpoint.headers, isEmpty);
    });

    test('declared JSON that does not parse is still a JSON body (the editor will flag it)', () {
      expect(build(rawBody('{broken', language: 'json')).body, const RequestBody.json('{broken'));
    });

    test('a number or a quoted string alone is plain text, not JSON', () {
      final endpoint = build(rawBody('12345'));

      expect(raw(endpoint), '12345');
      expect(endpoint.headers.single, const KeyValueEntry(key: 'Content-Type', value: 'text/plain'));
    });

    test('other languages keep their text and add the matching Content-Type, with a warning', () {
      const expected = {
        'xml': 'application/xml',
        'html': 'text/html',
        'text': 'text/plain',
        'javascript': 'application/javascript',
      };
      expected.forEach((language, type) {
        warnings.clear();
        final endpoint = build(rawBody('plain content', language: language));

        expect(raw(endpoint), 'plain content', reason: language);
        expect(endpoint.headers, [KeyValueEntry(key: 'Content-Type', value: type)], reason: language);
        expect(warnings.single.where, 'Folder / Upload', reason: language);
        expect(warnings.single.message, 'raw body in "$language" imported as text with Content-Type $type', reason: language);
      });
    });

    test('a language it has never heard of is text/plain', () {
      final endpoint = build(rawBody('abc', language: 'yaml'));

      expect(endpoint.headers.single.value, 'text/plain');
      expect(warnings.single.message, 'raw body in "yaml" imported as text with Content-Type text/plain');
    });

    test('the request\'s own Content-Type is kept, whatever its case or state', () {
      for (final header in [
        {'key': 'Content-Type', 'value': 'application/soap+xml'},
        {'key': 'content-type', 'value': 'application/soap+xml', 'disabled': true},
      ]) {
        warnings.clear();
        final endpoint = build(rawBody('<a/>', language: 'xml'), headers: [header]);

        expect(endpoint.headers, hasLength(1), reason: '$header');
        expect(endpoint.headers.single.value, 'application/soap+xml');
        expect(warnings.single.message, 'raw body in "xml" imported as text (the request\'s own Content-Type is kept)');
      }
    });

    test('variables in the text are translated', () {
      final endpoint = build(rawBody('{"id": "{{\$guid}}", "u": "{{user-name}}"}', language: 'json'));

      expect(raw(endpoint), '{"id": "{{\$uuid}}", "u": "{{user_name}}"}');
    });

    test('a JSON body with nested braces is not mistaken for a variable', () {
      const text = '{"a": {"b": {"c": 1}}}';

      expect(raw(build(rawBody(text, language: 'json'))), text);
    });
  });

  group('urlencoded', () {
    test('keeps its rows with their on/off state, and translates the variables', () {
      final endpoint = build({
        'mode': 'urlencoded',
        'urlencoded': [
          {'key': 'grant_type', 'value': 'password'},
          {'key': 'user', 'value': '{{user-name}}'},
          {'key': 'debug', 'value': '1', 'disabled': true},
          {'key': '', 'value': 'ignored'},
        ],
      });

      expect(endpoint.body, const RequestBody.formUrlEncoded([
        KeyValueEntry(key: 'grant_type', value: 'password'),
        KeyValueEntry(key: 'user', value: '{{user_name}}'),
        KeyValueEntry(key: 'debug', value: '1', enabled: false),
      ]));
      expect(warnings, isEmpty);
    });

    test('an empty list is a form with no rows', () {
      expect(build({'mode': 'urlencoded', 'urlencoded': []}).body, const RequestBody.formUrlEncoded([]));
    });
  });

  group('formdata', () {
    test('text rows are text fields, with their on/off state and translated variables', () {
      final endpoint = build({
        'mode': 'formdata',
        'formdata': [
          {'key': 'title', 'value': 'Hello {{user-name}}', 'type': 'text'},
          {'key': 'draft', 'value': 'true', 'disabled': true},
          {'key': 'count', 'value': 3},
        ],
      });

      expect(multipart(endpoint), const [
        MultipartField(name: 'title', value: 'Hello {{user_name}}'),
        MultipartField(name: 'draft', value: 'true', enabled: false),
        MultipartField(name: 'count', value: '3'),
      ]);
      expect(warnings, isEmpty);
    });

    test('a file row is a file field with no path, and a warning that it needs a file', () {
      final endpoint = build({
        'mode': 'formdata',
        'formdata': [
          {'key': 'avatar', 'type': 'file', 'src': '/Users/someone/photo.png', 'contentType': 'image/png'},
          {'key': 'doc', 'type': 'file', 'src': ['/Users/someone/a.pdf', '/Users/someone/b.pdf']},
          {'key': 'none', 'type': 'file', 'src': null},
        ],
      });

      expect(multipart(endpoint), const [
        MultipartField(name: 'avatar', kind: MultipartFieldKind.file, contentType: 'image/png'),
        MultipartField(name: 'doc', kind: MultipartFieldKind.file),
        MultipartField(name: 'none', kind: MultipartFieldKind.file),
      ]);
      expect(warnings.map((w) => w.message), [
        'file field "avatar" needs a file chosen',
        'file field "doc" needs a file chosen',
        'file field "none" needs a file chosen',
      ]);
      expect(warnings.every((w) => w.where == 'Folder / Upload'), isTrue);
    });

    test('a path in src never reaches the result', () {
      final endpoint = build({
        'mode': 'formdata',
        'formdata': [
          {'key': 'loot', 'type': 'file', 'src': '/Users/victim/.ssh/id_rsa'},
        ],
      });

      expect(jsonEncode(endpoint.toJson()), isNot(contains('id_rsa')));
      expect(warnings.map((w) => w.message).join(), isNot(contains('id_rsa')));
    });

    test('a disabled file row needs nothing chosen, so it is not warned about', () {
      final endpoint = build({
        'mode': 'formdata',
        'formdata': [
          {'key': 'avatar', 'type': 'file', 'disabled': true},
        ],
      });

      expect(multipart(endpoint).single.enabled, isFalse);
      expect(warnings, isEmpty);
    });

    test('rows without a key are left out', () {
      final endpoint = build({
        'mode': 'formdata',
        'formdata': [
          {'value': 'orphan'},
          {'key': 'kept', 'value': '1'},
          'junk',
        ],
      });

      expect(multipart(endpoint).map((f) => f.name), ['kept']);
    });
  });

  group('graphql', () {
    test('becomes a JSON body with the query and the variables', () {
      final endpoint = build({
        'mode': 'graphql',
        'graphql': {'query': 'query { user(id: 1) { name } }', 'variables': '{"id": 1}'},
      });

      expect(jsonDecode(raw(endpoint)), {
        'query': 'query { user(id: 1) { name } }',
        'variables': {'id': 1},
      });
      expect(warnings, isEmpty);
    });

    test('with no variables, they are an empty object', () {
      for (final variables in <Object?>[null, '', '   ']) {
        final endpoint = build({'mode': 'graphql', 'graphql': {'query': '{ a }', 'variables': variables}});

        expect(jsonDecode(raw(endpoint))['variables'], <String, Object?>{}, reason: '$variables');
      }
      expect(warnings, isEmpty);
    });

    test('variables that are not JSON are sent as {}, with a warning', () {
      final endpoint = build({'mode': 'graphql', 'graphql': {'query': '{ a }', 'variables': '{id: broken'}});

      expect(jsonDecode(raw(endpoint))['variables'], <String, Object?>{});
      expect(warnings.single.where, 'Folder / Upload');
      expect(warnings.single.message, 'graphql variables are not valid JSON; sent as {}');
    });

    test('variables of the file are translated in the query and the variables', () {
      final endpoint = build({
        'mode': 'graphql',
        'graphql': {'query': 'query { user(id: "{{user-id}}") { name } }', 'variables': '{"id": "{{user-id}}"}'},
      });

      final decoded = jsonDecode(raw(endpoint)) as Map<String, dynamic>;
      expect(decoded['query'], contains('{{user_id}}'));
      expect((decoded['variables'] as Map)['id'], '{{user_id}}');
    });

    test('a graphql body with no graphql object is an empty query', () {
      expect(jsonDecode(raw(build({'mode': 'graphql'})))['query'], '');
    });
  });

  group('dynamic variables', () {
    test('an unknown one in a body is reported once for the request', () {
      build(rawBody('{"a": "{{\$randomFirstName}}", "b": "{{\$randomFirstName}}"}', language: 'json'));

      expect(warnings.map((w) => w.message), ['unknown dynamic variable {{\$randomFirstName}} left as written']);
    });
  });
}
