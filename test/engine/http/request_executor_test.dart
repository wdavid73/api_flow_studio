import 'dart:convert';
import 'dart:io';

import 'package:api_flow_studio/engine/http/executed_response.dart';
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
          authConfig: const AuthConfig.basic(username: 'u-{{\$randomInt}}', password: 'p-{{\$randomString}}'),
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
      expect(decoded, matches(RegExp(r'^u-\d+:p-[a-z0-9]{12}$')));
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
      // dio gets the url and the params separately; requestUrl is the two together.
      expect(first.requestUrl, startsWith('${urls[0]}?n='));
      expect(second.requestUrl, startsWith('${urls[1]}?n='));
    });

    test('requestUrl includes the query params that were sent', () async {
      final response = await executor.execute(
        const Endpoint(
          id: 'e-q',
          groupId: 'g-1',
          name: 'Search',
          method: 'GET',
          url: 'https://api.test/items',
          queryParams: [
            KeyValueEntry(key: 'q', value: 'apple'),
            KeyValueEntry(key: 'page', value: '{{\$randomInt}}'),
            KeyValueEntry(key: 'off', value: 'x', enabled: false),
          ],
        ),
        variables: const {},
      );

      final uri = Uri.parse(response.requestUrl!);
      expect(uri.path, '/items');
      expect(uri.queryParameters.keys, ['q', 'page']);
      expect(uri.queryParameters['q'], 'apple');
      expect(uri.queryParameters['page'], matches(RegExp(r'^\d+$')));
    });

    test('requestUrl adds the params to a url that already has a query', () async {
      final response = await executor.execute(
        const Endpoint(
          id: 'e-q',
          groupId: 'g-1',
          name: 'Search',
          method: 'GET',
          url: 'https://api.test/items?sort=asc',
          queryParams: [KeyValueEntry(key: 'q', value: 'apple')],
        ),
        variables: const {},
      );

      expect(response.requestUrl, 'https://api.test/items?sort=asc&q=apple');
    });

    test('requestUrl is the url untouched when there are no query params', () async {
      final response = await executor.execute(
        const Endpoint(id: 'e-q', groupId: 'g-1', name: 'Plain', method: 'GET', url: '{{base}}/items'),
        variables: const {'base': 'https://api.test'},
      );

      expect(response.requestUrl, 'https://api.test/items');
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

  group('multipart body', () {
    late Directory tmp;
    late File png;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('executor_multipart_');
      png = File('${tmp.path}/avatar.png')..writeAsBytesSync(List.generate(300, (i) => i % 256));
      when(() => dio.request<dynamic>(
            any(),
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _response(statusCode: 201, data: {}));
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Endpoint upload(List<MultipartField> fields, {List<KeyValueEntry> headers = const []}) => Endpoint(
          id: 'e-up',
          groupId: 'g-1',
          name: 'Upload',
          method: 'POST',
          url: 'https://api.test/upload',
          headers: headers,
          body: RequestBody.multipart(fields),
        );

    Future<(FormData, Options)> sent(Endpoint endpoint, {Map<String, String> variables = const {}}) async {
      await executor.execute(endpoint, variables: variables);
      final captured = verify(() => dio.request<dynamic>(
            any(),
            data: captureAny(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: captureAny(named: 'options'),
          )).captured;
      return (captured[0] as FormData, captured[1] as Options);
    }

    test('sends the text fields and the file as a FormData, keeping repeated names', () async {
      final (form, _) = await sent(upload([
        const MultipartField(name: 'title', value: 'Hello'),
        const MultipartField(name: 'tag', value: 'a'),
        const MultipartField(name: 'tag', value: 'b'),
        MultipartField(name: 'avatar', kind: MultipartFieldKind.file, value: png.path),
      ]));

      expect(form.fields.map((e) => '${e.key}=${e.value}'), ['title=Hello', 'tag=a', 'tag=b']);
      final file = form.files.single;
      expect(file.key, 'avatar');
      expect(file.value.filename, 'avatar.png');
      expect(file.value.contentType.toString(), 'image/png');
      expect(file.value.length, 300);
    });

    test('an explicit content type wins, an unknown extension is octet-stream', () async {
      final bin = File('${tmp.path}/data.xyz')..writeAsBytesSync([1, 2, 3]);

      final (form, _) = await sent(upload([
        MultipartField(name: 'a', kind: MultipartFieldKind.file, value: png.path, contentType: 'application/x-custom'),
        MultipartField(name: 'b', kind: MultipartFieldKind.file, value: bin.path),
      ]));

      expect(form.files[0].value.contentType.toString(), 'application/x-custom');
      expect(form.files[1].value.contentType.toString(), 'application/octet-stream');
    });

    test('a content type cleared to empty is the same as none: inferred from the extension', () async {
      final (form, _) = await sent(upload([
        MultipartField(name: 'a', kind: MultipartFieldKind.file, value: png.path, contentType: ''),
      ]));

      expect(form.files.single.value.contentType.toString(), 'image/png');
    });

    test('disabled fields and fields without a name are left out', () async {
      final (form, _) = await sent(upload([
        const MultipartField(name: 'kept', value: '1'),
        const MultipartField(name: 'off', value: '2', enabled: false),
        const MultipartField(name: '', value: '3'),
        MultipartField(name: 'gone', kind: MultipartFieldKind.file, value: png.path, enabled: false),
      ]));

      expect(form.fields.map((e) => e.key), ['kept']);
      expect(form.files, isEmpty);
    });

    test('a Content-Type header set by hand is dropped so dio can add the boundary', () async {
      final (_, options) = await sent(upload(
        const [MultipartField(name: 'a', value: 'b')],
        headers: const [
          KeyValueEntry(key: 'content-type', value: 'multipart/form-data'),
          KeyValueEntry(key: 'X-Trace', value: '1'),
        ],
      ));

      expect(options.headers!.keys.map((k) => k.toLowerCase()), isNot(contains('content-type')));
      expect(options.headers!['X-Trace'], '1');
    });

    test('names, values, paths and content types are interpolated', () async {
      final (form, _) = await sent(
        upload([
          const MultipartField(name: '{{field}}', value: 'Hi {{who}}'),
          MultipartField(name: 'file', kind: MultipartFieldKind.file, value: '{{dir}}/avatar.png', contentType: '{{type}}'),
        ]),
        variables: {'field': 'title', 'who': 'Ana', 'dir': tmp.path, 'type': 'image/x-test'},
      );

      expect(form.fields.single.key, 'title');
      expect(form.fields.single.value, 'Hi Ana');
      expect(form.files.single.value.contentType.toString(), 'image/x-test');
    });

    group('a file that cannot be sent fails the request before anything is sent', () {
      Future<ExecutedResponse> fails(List<MultipartField> fields) async {
        final response = await executor.execute(upload(fields), variables: const {});
        verifyNever(() => dio.request<dynamic>(
              any(),
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
            ));
        expect(response.status, isNull);
        expect(response.requestUrl, 'https://api.test/upload');
        return response;
      }

      test('no file chosen', () async {
        final r = await fails([const MultipartField(name: 'avatar', kind: MultipartFieldKind.file)]);

        expect(r.error, 'Field "avatar" has no file chosen');
      });

      test('a file that does not exist', () async {
        final path = '${tmp.path}/missing.png';
        final r = await fails([MultipartField(name: 'avatar', kind: MultipartFieldKind.file, value: path)]);

        expect(r.error, startsWith('Cannot read the file for field "avatar": $path ('));
      });

      test('a folder', () async {
        final r = await fails([MultipartField(name: 'avatar', kind: MultipartFieldKind.file, value: tmp.path)]);

        expect(r.error, startsWith('Cannot read the file for field "avatar": ${tmp.path} ('));
      });

      test('a content type that is not one', () async {
        final r = await fails([
          MultipartField(name: 'avatar', kind: MultipartFieldKind.file, value: png.path, contentType: 'not a type'),
        ]);

        expect(r.error, 'Invalid content type "not a type" for field "avatar"');
      });

      test('a disabled file field is not checked', () async {
        await executor.execute(
          upload([const MultipartField(name: 'avatar', kind: MultipartFieldKind.file, enabled: false)]),
          variables: const {},
        );

        verify(() => dio.request<dynamic>(
              any(),
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
            )).called(1);
      });
    });

    test('each send builds its own FormData (a FormData can only be read once)', () async {
      final endpoint = upload([MultipartField(name: 'avatar', kind: MultipartFieldKind.file, value: png.path)]);

      await executor.execute(endpoint, variables: const {});
      await executor.execute(endpoint, variables: const {});

      final forms = verify(() => dio.request<dynamic>(
            any(),
            data: captureAny(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          )).captured;
      expect(identical(forms[0], forms[1]), isFalse);
    });
  });
}
