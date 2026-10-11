import 'dart:convert';

import 'package:api_flow_studio/engine/http/request_executor.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/variables/dynamic_values.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

Response<dynamic> _response({
  required int statusCode,
  dynamic data,
  Map<String, List<String>> headers = const {},
}) {
  return Response(
    requestOptions: RequestOptions(path: '/'),
    statusCode: statusCode,
    data: data,
    headers: Headers.fromMap(headers),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
  });

  late MockDio dio;
  late RequestExecutor executor;

  setUp(() {
    dio = MockDio();
    executor = RequestExecutor(dio: dio);
  });

  const baseEndpoint = Endpoint(
    id: 'e-1',
    groupId: 'g-1',
    name: 'Get user',
    method: 'GET',
    url: '{{base_url}}/users/{{id}}',
  );

  test('a 2xx response returns status/body/headers/elapsed/size without throwing', () async {
    when(() => dio.request<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer(
      (_) async => _response(
        statusCode: 200,
        data: {'id': '42'},
        headers: {
          'content-type': ['application/json'],
        },
      ),
    );

    final result = await executor.execute(baseEndpoint, variables: {
      'base_url': 'https://api.dev',
      'id': '42',
    });

    expect(result.status, 200);
    expect(result.body, {'id': '42'});
    expect(result.headers['content-type'], 'application/json');
    expect(result.elapsedMs, greaterThanOrEqualTo(0));
    expect(result.sizeBytes, greaterThan(0));
    expect(result.error, isNull);
  });

  test('the interpolated URL is what actually gets sent', () async {
    when(() => dio.request<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => _response(statusCode: 200));

    await executor.execute(baseEndpoint, variables: {
      'base_url': 'https://api.dev',
      'id': '42',
    });

    final captured = verify(() => dio.request<dynamic>(
          captureAny(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).captured;
    expect(captured.single, 'https://api.dev/users/42');
  });

  test('a 404 response comes back as a normal result, not an error', () async {
    when(() => dio.request<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => _response(statusCode: 404, data: 'not found'));

    final result = await executor.execute(baseEndpoint, variables: {
      'base_url': 'https://api.dev',
      'id': 'missing',
    });

    expect(result.status, 404);
    expect(result.error, isNull);
  });

  test('a connection error sets error and leaves status null, without throwing', () async {
    when(() => dio.request<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
        message: 'Connection refused',
      ),
    );

    final result = await executor.execute(baseEndpoint, variables: {
      'base_url': 'https://api.dev',
      'id': '1',
    });

    expect(result.status, isNull);
    expect(result.error, 'Connection refused');
  });

  test('a timeout sets error and leaves status null, without throwing', () async {
    when(() => dio.request<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionTimeout,
        message: 'Connection timed out',
      ),
    );

    final result = await executor.execute(baseEndpoint, variables: {
      'base_url': 'https://api.dev',
      'id': '1',
    });

    expect(result.status, isNull);
    expect(result.error, 'Connection timed out');
  });

  test('a json body is sent as-is with a Content-Type header', () async {
    when(() => dio.request<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => _response(statusCode: 201));

    final endpoint = baseEndpoint.copyWith(
      method: 'POST',
      body: const RequestBody.json('{"email":"{{user_email}}"}'),
    );

    await executor.execute(endpoint, variables: {
      'base_url': 'https://api.dev',
      'id': '1',
      'user_email': 'a@b.com',
    });

    final captured = verify(() => dio.request<dynamic>(
          any(),
          data: captureAny(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: captureAny(named: 'options'),
        )).captured;
    expect(captured[0], '{"email":"a@b.com"}');
    final options = captured[1] as Options;
    expect(options.headers?['Content-Type'], 'application/json');
  });

  test('a formUrlEncoded body sends only enabled fields as a map', () async {
    when(() => dio.request<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => _response(statusCode: 200));

    final endpoint = baseEndpoint.copyWith(
      method: 'POST',
      body: const RequestBody.formUrlEncoded([
        KeyValueEntry(key: 'grant_type', value: 'password'),
        KeyValueEntry(key: 'debug', value: 'true', enabled: false),
      ]),
    );

    await executor.execute(endpoint, variables: {'base_url': 'https://api.dev', 'id': '1'});

    final captured = verify(() => dio.request<dynamic>(
          any(),
          data: captureAny(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).captured;
    expect(captured.single, {'grant_type': 'password'});
  });

  test('AuthConfig.basic sets a base64 Basic Authorization header', () async {
    when(() => dio.request<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => _response(statusCode: 200));

    final endpoint = baseEndpoint.copyWith(
      authConfig: const AuthConfig.basic(username: 'alice', password: 'secret'),
    );

    await executor.execute(endpoint, variables: {'base_url': 'https://api.dev', 'id': '1'});

    final options = verify(() => dio.request<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: captureAny(named: 'options'),
        )).captured.single as Options;
    final expectedToken = base64Encode(utf8.encode('alice:secret'));
    expect(options.headers?['Authorization'], 'Basic $expectedToken');
  });

  test('AuthConfig.bearer sets a Bearer Authorization header with the resolved token', () async {
    when(() => dio.request<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => _response(statusCode: 200));

    final endpoint = baseEndpoint.copyWith(
      authConfig: const AuthConfig.bearer(token: '{{auth_token}}'),
    );

    await executor.execute(endpoint, variables: {
      'base_url': 'https://api.dev',
      'id': '1',
      'auth_token': 'abc123',
    });

    final options = verify(() => dio.request<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: captureAny(named: 'options'),
        )).captured.single as Options;
    expect(options.headers?['Authorization'], 'Bearer abc123');
  });

  test('AuthConfig.none sets no Authorization header', () async {
    when(() => dio.request<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => _response(statusCode: 200));

    await executor.execute(baseEndpoint, variables: {'base_url': 'https://api.dev', 'id': '1'});

    final options = verify(() => dio.request<dynamic>(
          any(),
          data: any(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: captureAny(named: 'options'),
        )).captured.single as Options;
    expect(options.headers?.containsKey('Authorization'), isFalse);
  });

  group('dynamic tokens', () {
    setUp(() {
      when(() => dio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _response(statusCode: 200, data: {}));
      executor = RequestExecutor(dio: dio, dynamicValues: DynamicValues());
    });

    const dynamicEndpoint = Endpoint(
      id: 'e-2',
      groupId: 'g-1',
      name: 'Create user',
      method: 'POST',
      url: 'https://api.test/users/{{\$uuid}}',
      headers: [KeyValueEntry(key: 'X-Request-Id', value: '{{\$uuid}}')],
      queryParams: [KeyValueEntry(key: 'n', value: '{{\$randomInt}}')],
      body: RequestBody.json('{"email":"{{\$randomEmail}}"}'),
      authConfig: AuthConfig.bearer(token: '{{\$randomString}}'),
    );

    test('are resolved in url, headers, query, json body and auth', () async {
      await executor.execute(dynamicEndpoint, variables: const {});

      final captured = verify(() => dio.request<dynamic>(
            captureAny(),
            data: captureAny(named: 'data'),
            queryParameters: captureAny(named: 'queryParameters'),
            options: captureAny(named: 'options'),
          )).captured;
      final url = captured[0] as String;
      final data = captured[1] as String;
      final query = captured[2] as Map<String, String>;
      final options = captured[3] as Options;

      expect(url, matches(RegExp(r'^https://api\.test/users/[0-9a-f-]{36}$')));
      expect(options.headers!['X-Request-Id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(query['n'], matches(RegExp(r'^\d+$')));
      expect(data, matches(RegExp(r'^\{"email":"test\.[a-z0-9]{8}@example\.com"\}$')));
      expect(options.headers!['Authorization'], matches(RegExp(r'^Bearer [a-z0-9]{12}$')));
    });

    test('are resolved in form-urlencoded fields and basic auth', () async {
      await executor.execute(
        dynamicEndpoint.copyWith(
          body: const RequestBody.formUrlEncoded([KeyValueEntry(key: 'e', value: '{{\$randomEmail}}')]),
          authConfig: const AuthConfig.basic(username: 'u-{{\$randomInt}}', password: 'p'),
        ),
        variables: const {},
      );
      final captured = verify(() => dio.request<dynamic>(
            any(),
            data: captureAny(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: captureAny(named: 'options'),
          )).captured;
      expect((captured[0] as Map)['e'], isNot(contains('{{')));
      final auth = (captured[1] as Options).headers!['Authorization'] as String;
      final decoded = utf8.decode(base64Decode(auth.substring('Basic '.length)));
      expect(decoded, matches(RegExp(r'^u-\d+:p$')));
    });

    test('two sends produce different values and requestUrl is the url sent', () async {
      final first = await executor.execute(dynamicEndpoint, variables: const {});
      final second = await executor.execute(dynamicEndpoint, variables: const {});

      expect(first.requestUrl, isNot(second.requestUrl));
      final urls = verify(() => dio.request<dynamic>(
            captureAny(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).captured.cast<String>();
      expect(urls, [first.requestUrl, second.requestUrl]);
    });

    test('requestUrl is also reported when the transport fails', () async {
      when(() => dio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenThrow(DioException(requestOptions: RequestOptions(path: '/'), message: 'boom'));

      final response = await executor.execute(dynamicEndpoint, variables: const {});

      expect(response.error, 'boom');
      expect(response.requestUrl, startsWith('https://api.test/users/'));
      expect(response.requestUrl, isNot(contains('{{')));
    });

    test('the default executor generates values so tokens never reach the server', () async {
      executor = RequestExecutor(dio: dio);
      final response = await executor.execute(dynamicEndpoint, variables: const {});
      expect(response.requestUrl, isNot(contains('{{')));
    });
  });
}
