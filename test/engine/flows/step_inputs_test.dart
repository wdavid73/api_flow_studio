import 'package:api_flow_studio/engine/flows/step_inputs.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Endpoint endpoint({
    String url = '/x',
    List<KeyValueEntry> queryParams = const [],
    List<KeyValueEntry> headers = const [],
    RequestBody body = const RequestBody.none(),
    AuthConfig auth = const AuthConfig.none(),
  }) =>
      Endpoint(
        id: 'e',
        groupId: 'g',
        name: 'n',
        method: 'GET',
        url: url,
        queryParams: queryParams,
        headers: headers,
        body: body,
        authConfig: auth,
      );

  test('finds variables in url, enabled query params and headers, in order, without duplicates', () {
    final e = endpoint(
      url: '{{base_url}}/users/{{user_id}}',
      queryParams: const [
        KeyValueEntry(key: 'region', value: '{{region}}'),
        KeyValueEntry(key: 'x', value: '{{off}}', enabled: false),
      ],
      headers: const [KeyValueEntry(key: 'X-Id', value: '{{user_id}}')],
    );

    expect(stepInputs(e).variables, ['base_url', 'user_id', 'region']);
  });

  test('reads the keys of query params and headers too', () {
    final e = endpoint(
      queryParams: const [KeyValueEntry(key: '{{param_name}}', value: '1')],
      headers: const [KeyValueEntry(key: '{{header_name}}', value: 'v')],
    );

    expect(stepInputs(e).variables, ['param_name', 'header_name']);
  });

  test('reads a json body', () {
    final e = endpoint(body: const RequestBody.json('{"email": "{{email}}", "pass": "{{password}}"}'));

    expect(stepInputs(e).variables, ['email', 'password']);
  });

  test('reads the enabled fields of a form-urlencoded body', () {
    final e = endpoint(
      body: const RequestBody.formUrlEncoded([
        KeyValueEntry(key: 'otp', value: '{{otp}}'),
        KeyValueEntry(key: 'off', value: '{{off}}', enabled: false),
      ]),
    );

    expect(stepInputs(e).variables, ['otp']);
  });

  test('reads name, value and content type of the enabled multipart fields', () {
    final e = endpoint(
      body: const RequestBody.multipart([
        MultipartField(name: '{{field}}', value: '{{fixtures}}/a.png', contentType: '{{mime}}'),
        MultipartField(name: 'off', value: '{{off}}', enabled: false),
      ]),
    );

    expect(stepInputs(e).variables, ['field', 'fixtures', 'mime']);
  });

  test('reads basic and bearer auth', () {
    expect(
      stepInputs(endpoint(auth: const AuthConfig.basic(username: '{{user}}', password: '{{pass}}'))).variables,
      ['user', 'pass'],
    );
    expect(stepInputs(endpoint(auth: const AuthConfig.bearer(token: '{{token}}'))).variables, ['token']);
  });

  test('separates generated tokens', () {
    final e = endpoint(
      url: '{{\$uuid}}/{{id}}',
      body: const RequestBody.json('{"e": "{{\$randomEmail}}", "again": "{{\$uuid}}"}'),
    );

    expect(stepInputs(e).variables, ['id']);
    expect(stepInputs(e).generated, ['uuid', 'randomEmail']);
  });

  test('ignores malformed tokens', () {
    final e = endpoint(url: '{{ id }}/{{user-id}}/{id}/{{}}');

    expect(stepInputs(e).variables, isEmpty);
    expect(stepInputs(e).generated, isEmpty);
  });
}
