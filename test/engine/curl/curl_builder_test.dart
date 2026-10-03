import 'package:api_flow_studio/engine/curl/curl_builder.dart';
import 'package:api_flow_studio/engine/curl/curl_parser.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Endpoint endpoint({
    String method = 'GET',
    String url = 'https://api.example.com/users',
    List<KeyValueEntry> headers = const [],
    List<KeyValueEntry> queryParams = const [],
    RequestBody body = const RequestBody.none(),
    AuthConfig auth = const AuthConfig.none(),
  }) =>
      Endpoint(
        id: 'e1',
        groupId: 'g1',
        name: 'Test',
        method: method,
        url: url,
        headers: headers,
        queryParams: queryParams,
        body: body,
        authConfig: auth,
      );

  test('a GET without body is a single line', () {
    expect(buildCurl(endpoint()), "curl -X GET 'https://api.example.com/users'");
  });

  test('a POST with a JSON body adds a Content-Type header and --data', () {
    final curl = buildCurl(endpoint(
      method: 'POST',
      body: const RequestBody.json('{"a":1}'),
    ));

    expect(curl, contains("curl -X POST 'https://api.example.com/users'"));
    expect(curl, contains("-H 'Content-Type: application/json'"));
    expect(curl, contains("--data '{\"a\":1}'"));
  });

  test('a form body is url-encoded into --data with the form Content-Type', () {
    final curl = buildCurl(endpoint(
      method: 'POST',
      body: const RequestBody.formUrlEncoded([
        KeyValueEntry(key: 'name', value: 'Ana Maria'),
        KeyValueEntry(key: 'off', value: 'x', enabled: false),
      ]),
    ));

    expect(curl, contains("-H 'Content-Type: application/x-www-form-urlencoded'"));
    expect(curl, contains("--data 'name=Ana%20Maria'"));
    expect(curl, isNot(contains('off=')));
  });

  test('an explicit Content-Type header is not duplicated', () {
    final curl = buildCurl(endpoint(
      method: 'POST',
      headers: const [KeyValueEntry(key: 'Content-Type', value: 'application/vnd.api+json')],
      body: const RequestBody.json('{}'),
    ));

    expect('Content-Type'.allMatches(curl), hasLength(1));
    expect(curl, contains('application/vnd.api+json'));
  });

  test('enabled query params are appended to the URL, disabled ones omitted', () {
    final curl = buildCurl(endpoint(
      queryParams: const [
        KeyValueEntry(key: 'active', value: 'true'),
        KeyValueEntry(key: 'q', value: 'a b'),
        KeyValueEntry(key: 'skip', value: '1', enabled: false),
      ],
    ));

    expect(curl, "curl -X GET 'https://api.example.com/users?active=true&q=a%20b'");
  });

  test('query params join with & when the URL already has a query string', () {
    final curl = buildCurl(endpoint(
      url: 'https://api.example.com/users?x=1',
      queryParams: const [KeyValueEntry(key: 'y', value: '2')],
    ));

    expect(curl, "curl -X GET 'https://api.example.com/users?x=1&y=2'");
  });

  test('disabled headers are omitted and enabled ones become -H lines', () {
    final curl = buildCurl(endpoint(headers: const [
      KeyValueEntry(key: 'X-Trace', value: 'abc'),
      KeyValueEntry(key: 'X-Skip', value: 'no', enabled: false),
    ]));

    expect(curl, contains("-H 'X-Trace: abc'"));
    expect(curl, isNot(contains('X-Skip')));
  });

  test('bearer and basic auth become an Authorization header', () {
    expect(
      buildCurl(endpoint(auth: const AuthConfig.bearer(token: 'tok'))),
      contains("-H 'Authorization: Bearer tok'"),
    );
    // base64("ana:secret") == YW5hOnNlY3JldA==
    expect(
      buildCurl(endpoint(auth: const AuthConfig.basic(username: 'ana', password: 'secret'))),
      contains("-H 'Authorization: Basic YW5hOnNlY3JldA=='"),
    );
  });

  test('single quotes are escaped in the URL, headers and body', () {
    final curl = buildCurl(endpoint(
      method: 'POST',
      url: "https://api.example.com/it's",
      headers: const [KeyValueEntry(key: 'X-Note', value: "it's")],
      body: const RequestBody.json("{\"q\":\"it's\"}"),
    ));

    expect(curl, contains(r"'https://api.example.com/it'\''s'"));
    expect(curl, contains(r"-H 'X-Note: it'\''s'"));
    expect(curl, contains('--data \'{"q":"it' r"'\''" 's"}\''));
  });

  test('{{variables}} are resolved from the given map and unknown ones stay literal', () {
    final curl = buildCurl(
      endpoint(
        url: '{{base_url}}/users/{{id}}',
        headers: const [KeyValueEntry(key: 'X-Key', value: '{{api_key}}')],
      ),
      variables: const {'base_url': 'https://staging.example.com', 'api_key': 'k1'},
    );

    expect(curl, contains("'https://staging.example.com/users/{{id}}'"));
    expect(curl, contains("-H 'X-Key: k1'"));
  });

  test('multi-line output joins parts with a backslash continuation', () {
    final curl = buildCurl(endpoint(
      method: 'POST',
      body: const RequestBody.json('{}'),
    ));

    expect(curl.split('\n').first, endsWith(r' \'));
  });

  test('parsing the built command gives back the same method, URL, headers and body', () {
    final original = endpoint(
      method: 'POST',
      url: 'https://api.example.com/users',
      headers: const [KeyValueEntry(key: 'X-Trace', value: "it's here")],
      body: const RequestBody.json('{"name":"Ana"}'),
    );

    final parsed = parseCurl(buildCurl(original));

    expect(parsed.method, 'POST');
    expect(parsed.url, 'https://api.example.com/users');
    expect(
      parsed.headers.map((h) => '${h.key}: ${h.value}'),
      containsAll(["X-Trace: it's here", 'Content-Type: application/json']),
    );
    expect((parsed.body as RequestBodyJson).raw, '{"name":"Ana"}');
  });
}
