import 'package:api_flow_studio/engine/curl/curl_builder.dart';
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

  group('multipart (-F / --form / --form-string)', () {
    List<MultipartField> fieldsOf(Endpoint e) =>
        e.body.maybeMap(multipart: (b) => b.fields, orElse: () => throw StateError('body is ${e.body}'));

    test('-F name=value is a text field, and a form implies POST', () {
      final endpoint = parseCurl("curl -F 'title=Hello' https://api.example.com/upload");

      expect(endpoint.method, 'POST');
      expect(fieldsOf(endpoint), [const MultipartField(name: 'title', value: 'Hello')]);
    });

    test('an explicit -X wins over the implied POST', () {
      expect(parseCurl("curl -X PUT -F a=b https://x.test").method, 'PUT');
    });

    test('-F name=@path is a file field', () {
      final endpoint = parseCurl("curl -F 'avatar=@/tmp/a.png' https://x.test");

      expect(fieldsOf(endpoint), [
        const MultipartField(name: 'avatar', kind: MultipartFieldKind.file, value: '/tmp/a.png'),
      ]);
    });

    test('--form is the long form and several fields keep their order', () {
      final endpoint = parseCurl("curl --form a=1 --form 'f=@/tmp/x.txt' --form b=2 https://x.test");

      expect(fieldsOf(endpoint).map((f) => f.name), ['a', 'f', 'b']);
      expect(fieldsOf(endpoint)[1].kind, MultipartFieldKind.file);
    });

    test(';type= becomes the content type and ;filename= is ignored', () {
      final endpoint = parseCurl("curl -F 'doc=@/tmp/a.bin;type=application/x-custom;filename=other.bin' https://x.test");

      expect(fieldsOf(endpoint).single, const MultipartField(
        name: 'doc',
        kind: MultipartFieldKind.file,
        value: '/tmp/a.bin',
        contentType: 'application/x-custom',
      ));
    });

    test('a double-quoted path keeps its semicolons, commas, spaces and escaped quotes', () {
      final endpoint = parseCurl(r"""curl -F 'a=@"/tmp/semi;colon, and space.png";type=image/png' -F 'b=@"/tmp/say \"hi\".png"' https://x.test""");

      expect(fieldsOf(endpoint)[0].value, '/tmp/semi;colon, and space.png');
      expect(fieldsOf(endpoint)[0].contentType, 'image/png');
      expect(fieldsOf(endpoint)[1].value, '/tmp/say "hi".png');
    });

    test('--form-string never reads @ or < specially', () {
      final endpoint = parseCurl("curl --form-string 'note=@not-a-file' --form-string 'x=<nor-this' https://x.test");

      expect(fieldsOf(endpoint), [
        const MultipartField(name: 'note', value: '@not-a-file'),
        const MultipartField(name: 'x', value: '<nor-this'),
      ]);
    });

    test('name=<path (file contents as text) is not supported and stays literal text', () {
      expect(fieldsOf(parseCurl("curl -F 'bio=<bio.txt' https://x.test")).single, const MultipartField(name: 'bio', value: '<bio.txt'));
    });

    test('a value may contain = and an empty value is allowed', () {
      final fields = fieldsOf(parseCurl("curl -F 'q=a=b' -F 'empty=' https://x.test"));

      expect(fields[0].value, 'a=b');
      expect(fields[1].value, '');
    });

    test('a field without = is rejected', () {
      expect(() => parseCurl("curl -F novalue https://x.test"), throwsA(isA<CurlParseException>().having((e) => e.message, 'message', contains('novalue'))));
    });

    test('-F without a value is rejected', () {
      expect(() => parseCurl('curl https://x.test -F'), throwsA(isA<CurlParseException>().having((e) => e.message, 'message', contains('-F'))));
    });

    test('mixing --form with --data is rejected, as curl does', () {
      expect(
        () => parseCurl("curl -F a=b -d 'c=d' https://x.test"),
        throwsA(isA<CurlParseException>().having((e) => e.message, 'message', 'Cannot mix --form with --data')),
      );
    });

    test('headers, auth and the url still parse next to a form', () {
      final endpoint = parseCurl("curl -u me:pw -H 'X-Trace: 1' -F a=b https://x.test/up");

      expect(endpoint.url, 'https://x.test/up');
      expect(endpoint.headers, [const KeyValueEntry(key: 'X-Trace', value: '1')]);
      expect(endpoint.authConfig, const AuthConfig.basic(username: 'me', password: 'pw'));
    });

    test('what buildCurl writes, parseCurl reads back', () {
      const original = [
        MultipartField(name: 'title', value: "it's; fine"),
        MultipartField(name: 'plain', kind: MultipartFieldKind.file, value: '/tmp/a.png'),
        MultipartField(name: 'odd', kind: MultipartFieldKind.file, value: '/tmp/with space;and "quotes".txt', contentType: 'text/plain'),
      ];
      final curl = buildCurl(const Endpoint(
        id: 'e',
        groupId: 'g',
        name: 'n',
        method: 'POST',
        url: 'https://x.test/up',
        body: RequestBody.multipart(original),
      ));

      expect(fieldsOf(parseCurl(curl)), original);
    });
  });
}
