import 'package:api_flow_studio/engine/import/foreign_variables.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Endpoint request({
    String name = 'Get pet',
    String url = '{{base_url}}/pets',
    List<KeyValueEntry> headers = const [],
    List<KeyValueEntry> query = const [],
    RequestBody body = const RequestBody.none(),
    AuthConfig auth = const AuthConfig.none(),
  }) =>
      Endpoint(id: 'e', groupId: 'g', name: name, method: 'GET', url: url, headers: headers, queryParams: query, body: body, authConfig: auth);

  List<String> found(List<Endpoint> endpoints, {Set<String> defined = const {'base_url'}}) =>
      [for (final w in undefinedVariableWarnings(endpoints, defined)) '${w.where}|${w.message}'];

  test('a variable the import defines is not a surprise', () {
    expect(found([request()]), isEmpty);
  });

  test('a variable nobody defines is named once, where it was first used', () {
    final result = found([
      request(name: 'A', query: [KeyValueEntry(key: 'q', value: '{{token}}')]),
      request(name: 'B', headers: [KeyValueEntry(key: 'X', value: '{{token}}')]),
    ]);

    expect(result, hasLength(1));
    expect(result.single, startsWith('A|'));
    expect(result.single, contains('{{token}}'));
    expect(result.single, contains('not defined by this file'));
  });

  test('every place a value can be is looked at', () {
    final endpoints = [
      request(name: 'url', url: '{{base_url}}/{{inUrl}}'),
      request(name: 'header', headers: [KeyValueEntry(key: '{{inHeaderKey}}', value: 'x')]),
      request(name: 'json', body: const RequestBody.json('{"a": "{{inJson}}"}')),
      request(name: 'form', body: RequestBody.formUrlEncoded([KeyValueEntry(key: 'a', value: '{{inForm}}')])),
      request(name: 'multipart', body: RequestBody.multipart([const MultipartField(name: 'a', value: '{{inMultipart}}')])),
      request(name: 'bearer', auth: const AuthConfig.bearer(token: '{{inBearer}}')),
      request(name: 'basic', auth: const AuthConfig.basic(username: '{{inUser}}', password: '{{inPass}}')),
    ];

    final names = [for (final w in undefinedVariableWarnings(endpoints, {'base_url'})) w.message.substring(0, w.message.indexOf('}}') + 2)];

    expect(names, [
      '{{inUrl}}', '{{inHeaderKey}}', '{{inJson}}', '{{inForm}}', '{{inMultipart}}', '{{inBearer}}', '{{inUser}}', '{{inPass}}',
    ]);
  });

  test('a generated value ({{\$uuid}}) is built in, not foreign', () {
    expect(found([request(url: '{{base_url}}/{{\$uuid}}')]), isEmpty);
  });

  test('a disabled row is not sent, so it is not a surprise either', () {
    expect(found([request(query: [KeyValueEntry(key: 'q', value: '{{token}}', enabled: false)])]), isEmpty);
  });
}
