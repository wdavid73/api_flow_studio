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

  Endpoint build(Map<String, dynamic> item, {String path = 'Folder / Item'}) => requestToEndpoint(
        item: item,
        id: 'e1',
        groupId: 'g1',
        path: path,
        translator: translator,
        warnings: warnings,
      );

  Map<String, dynamic> item({Object? request, String? name = 'My request', Object? description}) => {
        'name': ?name,
        'request': request,
        'description': ?description,
      };

  group('the request as a whole', () {
    test('a request given as text is a GET to that url', () {
      final endpoint = build(item(request: 'https://api.test/users'));

      expect(endpoint.method, 'GET');
      expect(endpoint.url, 'https://api.test/users');
      expect(endpoint.id, 'e1');
      expect(endpoint.groupId, 'g1');
      expect(endpoint.name, 'My request');
    });

    test('the method is upper-cased, and GET when it is missing or blank', () {
      expect(build(item(request: {'method': 'post', 'url': 'https://x.test'})).method, 'POST');
      expect(build(item(request: {'url': 'https://x.test'})).method, 'GET');
      expect(build(item(request: {'method': '  ', 'url': 'https://x.test'})).method, 'GET');
    });

    test('with no name, the method and url name it', () {
      expect(build(item(name: null, request: {'method': 'DELETE', 'url': 'https://x.test/a'})).name, 'DELETE https://x.test/a');
      expect(build(item(name: '   ', request: 'https://x.test/b')).name, 'GET https://x.test/b');
    });

    test('a request that is not a request at all still gives an endpoint', () {
      final endpoint = build(item(request: 42));

      expect(endpoint.method, 'GET');
      expect(endpoint.url, '');
      expect(endpoint.headers, isEmpty);
    });

    test('no body and no authentication at this stage', () {
      final endpoint = build(item(request: 'https://x.test'));

      expect(endpoint.body, const RequestBody.none());
      expect(endpoint.authConfig, const AuthConfig.none());
    });

    test('the description is text, or the content of an object, from the request or the item', () {
      expect(build(item(request: {'url': 'https://x.test', 'description': 'On the request'})).description, 'On the request');
      expect(build(item(request: {'url': 'https://x.test', 'description': {'content': 'In an object', 'type': 'text/markdown'}})).description, 'In an object');
      expect(build(item(request: {'url': 'https://x.test'}, description: 'On the item')).description, 'On the item');
      expect(build(item(request: {'url': 'https://x.test', 'description': 'wins'}, description: 'loses')).description, 'wins');
      expect(build(item(request: 'https://x.test')).description, '');
    });

    test('the description is prose: its braces are left alone', () {
      expect(build(item(request: {'url': 'https://x.test', 'description': 'Use {{base-url}} here'})).description, 'Use {{base-url}} here');
    });
  });

  group('the url', () {
    Endpoint withUrl(Object? url) => build(item(request: {'url': url}));

    test('as text, it is the base and the params after the ?', () {
      final endpoint = withUrl('https://api.test/users?page=2&sort=name');

      expect(endpoint.url, 'https://api.test/users');
      expect(endpoint.queryParams, [
        const KeyValueEntry(key: 'page', value: '2'),
        const KeyValueEntry(key: 'sort', value: 'name'),
      ]);
    });

    test('as an object, the base is raw without its query and the params come from query', () {
      final endpoint = withUrl({
        'raw': 'https://api.test/users?page=2',
        'query': [
          {'key': 'page', 'value': '2'},
          {'key': 'debug', 'value': 'true', 'disabled': true},
        ],
      });

      expect(endpoint.url, 'https://api.test/users');
      expect(endpoint.queryParams, [
        const KeyValueEntry(key: 'page', value: '2'),
        const KeyValueEntry(key: 'debug', value: 'true', enabled: false),
      ]);
    });

    test('an object with raw but no query list reads the params from raw', () {
      final endpoint = withUrl({'raw': 'https://api.test/users?a=1'});

      expect(endpoint.queryParams, [const KeyValueEntry(key: 'a', value: '1')]);
    });

    test('an object without raw is put together from its parts', () {
      final endpoint = withUrl({
        'protocol': 'https',
        'host': ['api', 'test'],
        'port': '8443',
        'path': ['v1', 'users'],
        'query': [
          {'key': 'a', 'value': '1'},
        ],
      });

      expect(endpoint.url, 'https://api.test:8443/v1/users');
      expect(endpoint.queryParams, [const KeyValueEntry(key: 'a', value: '1')]);
    });

    test('the parts may also be plain text, and a variable can be the host', () {
      expect(withUrl({'host': '{{base_url}}', 'path': 'users/1'}).url, '{{base_url}}/users/1');
      expect(withUrl({'host': ['{{base_url}}'], 'path': []}).url, '{{base_url}}');
    });

    test('params keep a variable value, an empty value and a key with no value', () {
      final endpoint = withUrl('{{base_url}}/search?q={{term}}&empty=&flag');

      expect(endpoint.url, '{{base_url}}/search');
      expect(endpoint.queryParams, [
        const KeyValueEntry(key: 'q', value: '{{term}}'),
        const KeyValueEntry(key: 'empty', value: ''),
        const KeyValueEntry(key: 'flag', value: ''),
      ]);
    });

    test('percent-encoding in a url string is undone, so dio does not encode it twice', () {
      final endpoint = withUrl('https://x.test/s?q=a%20b%26c&n=caf%C3%A9');

      expect(endpoint.queryParams.map((p) => p.value), ['a b&c', 'café']);
    });

    test('a url with no query has no params', () {
      expect(withUrl('https://x.test/a').queryParams, isEmpty);
      expect(withUrl('https://x.test/a?').queryParams, isEmpty);
    });

    test('a url that is not text or an object is empty', () {
      expect(withUrl(null).url, '');
      expect(withUrl(7).url, '');
    });

    test('a port inside a host name is not a path variable', () {
      expect(withUrl('http://localhost:3000/users').url, 'http://localhost:3000/users');
      expect(withUrl('localhost:3000/users').url, 'localhost:3000/users');
    });

    test('variables in the url and the params are translated, and renames are remembered', () {
      final endpoint = withUrl('{{base-url}}/users?token={{api key}}');

      expect(endpoint.url, '{{base_url}}/users');
      expect(endpoint.queryParams.single.value, '{{api_key}}');
      expect(translator.renamed, {'base-url': 'base_url', 'api key': 'api_key'});
    });
  });

  group('path variables', () {
    test('take the value that the url declares', () {
      final endpoint = build(item(request: {
        'url': {
          'raw': '{{base_url}}/users/:id/posts/:postId',
          'variable': [
            {'key': 'id', 'value': '42'},
            {'key': 'postId', 'value': '{{post-id}}'},
          ],
        },
      }));

      expect(endpoint.url, '{{base_url}}/users/42/posts/{{post_id}}');
      expect(warnings, isEmpty);
    });

    test('with no value are written as a variable, and warned', () {
      final endpoint = build(item(request: {
        'url': {
          'raw': '{{base_url}}/users/:id',
          'variable': [
            {'key': 'id', 'value': ''},
          ],
        },
      }));

      expect(endpoint.url, '{{base_url}}/users/{{id}}');
      expect(warnings, hasLength(1));
      expect(warnings.single.where, 'Folder / Item');
      expect(warnings.single.message, 'path variable :id has no value; written as {{id}}');
    });

    test('that the url never declares are treated the same way', () {
      final endpoint = build(item(request: 'https://x.test/orders/:orderId'));

      expect(endpoint.url, 'https://x.test/orders/{{orderId}}');
      expect(warnings.single.message, 'path variable :orderId has no value; written as {{orderId}}');
    });

    test('a colon in the middle of a segment is just a colon', () {
      final endpoint = build(item(request: 'https://x.test/files/report:v2/download/id:abc/'));

      expect(endpoint.url, 'https://x.test/files/report:v2/download/id:abc/');
      expect(warnings, isEmpty);
    });

    test('only count in the path, not in the query', () {
      final endpoint = build(item(request: 'https://x.test/a?next=/:id'));

      expect(endpoint.url, 'https://x.test/a');
      expect(endpoint.queryParams.single.value, '/:id');
      expect(warnings, isEmpty);
    });

    test('the same one used twice is warned once', () {
      build(item(request: 'https://x.test/:id/copy/:id'));

      expect(warnings, hasLength(1));
    });
  });

  group('headers', () {
    List<KeyValueEntry> headersOf(Object? header) => build(item(request: {'url': 'https://x.test', 'header': header})).headers;

    test('keep their order and their on/off state', () {
      expect(headersOf([
        {'key': 'Accept', 'value': 'application/json'},
        {'key': 'X-Debug', 'value': '1', 'disabled': true},
        {'key': 'Accept', 'value': 'text/plain'},
      ]), [
        const KeyValueEntry(key: 'Accept', value: 'application/json'),
        const KeyValueEntry(key: 'X-Debug', value: '1', enabled: false),
        const KeyValueEntry(key: 'Accept', value: 'text/plain'),
      ]);
    });

    test('translate their variables', () {
      final headers = headersOf([
        {'key': 'Authorization', 'value': 'Bearer {{access-token}}'},
        {'key': 'X-Request-Id', 'value': '{{\$guid}}'},
      ]);

      expect(headers[0].value, 'Bearer {{access_token}}');
      expect(headers[1].value, '{{\$uuid}}');
    });

    test('a value that is not text is written out, and a missing one is empty', () {
      expect(headersOf([
        {'key': 'X-Count', 'value': 5},
        {'key': 'X-Empty'},
      ]), [
        const KeyValueEntry(key: 'X-Count', value: '5'),
        const KeyValueEntry(key: 'X-Empty', value: ''),
      ]);
    });

    test('rows without a key are left out', () {
      expect(headersOf([
        {'value': 'orphan'},
        {'key': '', 'value': 'blank'},
        'not a map',
        {'key': 'Kept', 'value': '1'},
      ]).map((h) => h.key), ['Kept']);
    });

    test('an old-style header block of text lines is read too', () {
      expect(headersOf('Accept: application/json\nX-Trace: abc:def\n\nbad line'), [
        const KeyValueEntry(key: 'Accept', value: 'application/json'),
        const KeyValueEntry(key: 'X-Trace', value: 'abc:def'),
      ]);
    });

    test('none at all, or something else, is no headers', () {
      expect(headersOf(null), isEmpty);
      expect(headersOf(<Object?>[]), isEmpty);
      expect(headersOf(12), isEmpty);
    });
  });

  group('dynamic variables', () {
    test('an unknown one is reported once for the request, with its path', () {
      build(item(request: {
        'url': 'https://x.test/{{\$randomFirstName}}',
        'header': [
          {'key': 'X-Name', 'value': '{{\$randomFirstName}}'},
          {'key': 'X-City', 'value': '{{\$randomCity}}'},
        ],
      }), path: 'Users / Create');

      expect(warnings.map((w) => '${w.where}: ${w.message}'), [
        'Users / Create: unknown dynamic variable {{\$randomFirstName}} left as written',
        'Users / Create: unknown dynamic variable {{\$randomCity}} left as written',
      ]);
    });
  });
}
