import 'package:api_flow_studio/engine/models/file_paths.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

Endpoint upload(List<MultipartField> fields) => Endpoint(
      id: 'e',
      groupId: 'g',
      name: 'Upload',
      method: 'POST',
      url: '/up',
      body: RequestBody.multipart(fields),
    );

void main() {
  group('fileBaseName', () {
    test('is the last segment, with either kind of separator', () {
      expect(fileBaseName('/tmp/dir/avatar.png'), 'avatar.png');
      expect(fileBaseName(r'C:\\Users\\ana\\scan.pdf'), 'scan.pdf');
      expect(fileBaseName('mixed/path\\file.txt'), 'file.txt');
    });

    test('is the whole text when there is no separator', () {
      expect(fileBaseName('avatar.png'), 'avatar.png');
    });

    test('is empty for an empty path or one that ends in a separator', () {
      expect(fileBaseName(''), '');
      expect(fileBaseName('/tmp/dir/'), '');
    });
  });

  group('withoutFilePaths', () {
    List<MultipartField> fieldsOf(Endpoint e) =>
        e.body.maybeMap(multipart: (b) => b.fields, orElse: () => throw StateError('not multipart'));

    test('empties the path of every file field and keeps everything else', () {
      final cleaned = withoutFilePaths(upload(const [
        MultipartField(name: 'title', value: 'Hello'),
        MultipartField(name: 'avatar', kind: MultipartFieldKind.file, value: '/home/ana/a.png', contentType: 'image/png'),
        MultipartField(name: 'doc', kind: MultipartFieldKind.file, value: '{{dir}}/b.pdf', enabled: false),
      ]));

      expect(fieldsOf(cleaned), const [
        MultipartField(name: 'title', value: 'Hello'),
        MultipartField(name: 'avatar', kind: MultipartFieldKind.file, contentType: 'image/png'),
        MultipartField(name: 'doc', kind: MultipartFieldKind.file, enabled: false),
      ]);
    });

    test('a path made of a {{variable}} is cleared too: it can point anywhere', () {
      final cleaned = withoutFilePaths(upload(const [
        MultipartField(name: 'f', kind: MultipartFieldKind.file, value: '{{secret_dir}}/key'),
      ]));

      expect(fieldsOf(cleaned).single.value, '');
    });

    test('text fields that look like paths are text, and stay', () {
      final cleaned = withoutFilePaths(upload(const [MultipartField(name: 'note', value: '/home/ana/a.png')]));

      expect(fieldsOf(cleaned).single.value, '/home/ana/a.png');
    });

    test('returns the same endpoint when there is nothing to clear', () {
      final noFiles = upload(const [MultipartField(name: 'a', value: 'b')]);
      final emptyPath = upload(const [MultipartField(name: 'f', kind: MultipartFieldKind.file)]);
      const json = Endpoint(id: 'e', groupId: 'g', name: 'n', method: 'POST', url: '/', body: RequestBody.json('{}'));

      expect(identical(withoutFilePaths(noFiles), noFiles), isTrue);
      expect(identical(withoutFilePaths(emptyPath), emptyPath), isTrue);
      expect(identical(withoutFilePaths(json), json), isTrue);
    });

    test('leaves the rest of the endpoint alone', () {
      final original = upload(const [MultipartField(name: 'f', kind: MultipartFieldKind.file, value: '/x')])
          .copyWith(headers: const [KeyValueEntry(key: 'X', value: '1')], authConfig: const AuthConfig.bearer(token: 't'));

      final cleaned = withoutFilePaths(original);

      expect(cleaned.headers, original.headers);
      expect(cleaned.authConfig, original.authConfig);
      expect(cleaned.url, original.url);
    });
  });

  group('filePathsToFill', () {
    test('counts the enabled file fields of every endpoint', () {
      final count = filePathsToFill([
        upload(const [
          MultipartField(name: 'a', kind: MultipartFieldKind.file, value: '/x'),
          MultipartField(name: 'b', kind: MultipartFieldKind.file),
          MultipartField(name: 'c', kind: MultipartFieldKind.file, enabled: false),
          MultipartField(name: 'd', value: 'text'),
          MultipartField(name: '', kind: MultipartFieldKind.file),
        ]),
        upload(const [MultipartField(name: 'e', kind: MultipartFieldKind.file)]),
        const Endpoint(id: 'j', groupId: 'g', name: 'n', method: 'POST', url: '/', body: RequestBody.json('{}')),
      ]);

      expect(count, 3);
    });
  });
}
