import 'package:api_flow_studio/engine/curl/curl_parser.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a simple curl <url> parses to a GET endpoint with no headers/body', () {
    final endpoint = parseCurl('curl https://api.example.com/users');

    expect(endpoint.method, 'GET');
    expect(endpoint.url, 'https://api.example.com/users');
    expect(endpoint.headers, isEmpty);
    expect(endpoint.body, const RequestBody.none());
  });

  test('-X POST -H header -d json body parses method, header, and json body', () {
    final endpoint = parseCurl(
      "curl -X POST -H 'Content-Type: application/json' -d '{\"a\":1}' https://api.example.com/users",
    );

    expect(endpoint.method, 'POST');
    expect(endpoint.url, 'https://api.example.com/users');
    expect(endpoint.headers, [const KeyValueEntry(key: 'Content-Type', value: 'application/json')]);
    expect(endpoint.body, const RequestBody.json('{"a":1}'));
  });

  test('-d without -X implies POST', () {
    final endpoint = parseCurl("curl -d 'a=1' https://api.example.com/users");

    expect(endpoint.method, 'POST');
  });

  test('-d with a form-urlencoded Content-Type header parses a form body', () {
    final endpoint = parseCurl(
      "curl -H 'Content-Type: application/x-www-form-urlencoded' -d 'a=1&b=2' https://api.example.com/users",
    );

    expect(
      endpoint.body,
      const RequestBody.formUrlEncoded([
        KeyValueEntry(key: 'a', value: '1'),
        KeyValueEntry(key: 'b', value: '2'),
      ]),
    );
  });

  test('-u alice:secret maps to AuthConfig.basic', () {
    final endpoint = parseCurl('curl -u alice:secret https://api.example.com/users');

    expect(endpoint.authConfig, const AuthConfig.basic(username: 'alice', password: 'secret'));
  });

  test('a multi-line command with backslash continuations parses like its single-line equivalent',
      () {
    const multiLine = '''
curl 'https://api.example.com/users' \\
  -H 'Content-Type: application/json' \\
  -H 'Authorization: Bearer abc123' \\
  --data-raw '{"name":"Alex"}' \\
  --compressed
''';

    final endpoint = parseCurl(multiLine);

    expect(endpoint.method, 'POST');
    expect(endpoint.url, 'https://api.example.com/users');
    expect(endpoint.headers, [
      const KeyValueEntry(key: 'Content-Type', value: 'application/json'),
      const KeyValueEntry(key: 'Authorization', value: 'Bearer abc123'),
    ]);
    expect(endpoint.body, const RequestBody.json('{"name":"Alex"}'));
  });

  test('a real Chrome devtools "Copy as cURL (bash)" sample parses correctly', () {
    const devtoolsSample = r'''
curl 'https://api.dev.example.com/api/v1/auth/login' \
  -H 'accept: application/json' \
  -H 'accept-language: en-US,en;q=0.9' \
  -H 'content-type: application/json' \
  -H 'origin: https://app.example.com' \
  -H 'user-agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' \
  --data-raw '{"email":"user@example.com","password":"hunter2"}' \
  --compressed
''';

    final endpoint = parseCurl(devtoolsSample);

    expect(endpoint.method, 'POST');
    expect(endpoint.url, 'https://api.dev.example.com/api/v1/auth/login');
    expect(endpoint.headers.length, 5);
    expect(
      endpoint.headers.firstWhere((h) => h.key == 'content-type').value,
      'application/json',
    );
    expect(endpoint.body, const RequestBody.json('{"email":"user@example.com","password":"hunter2"}'));
  });

  test('ignores unrecognized flags like -s, -k, -i, -L, --compressed', () {
    final endpoint = parseCurl("curl -s -k -i -L --compressed https://api.example.com/health");

    expect(endpoint.method, 'GET');
    expect(endpoint.url, 'https://api.example.com/health');
  });

  test('an empty or blank input throws CurlParseException', () {
    expect(() => parseCurl(''), throwsA(isA<CurlParseException>()));
    expect(() => parseCurl('   '), throwsA(isA<CurlParseException>()));
  });

  test('input with no URL throws CurlParseException', () {
    expect(() => parseCurl('curl -X POST'), throwsA(isA<CurlParseException>()));
  });

  test('an unterminated quote throws CurlParseException', () {
    expect(() => parseCurl("curl -H 'Content-Type: application/json https://x.com"),
        throwsA(isA<CurlParseException>()));
  });

  test('a malformed header (no colon) throws CurlParseException', () {
    expect(() => parseCurl("curl -H 'not-a-header' https://x.com"),
        throwsA(isA<CurlParseException>()));
  });
}
