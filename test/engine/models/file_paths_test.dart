import 'package:api_flow_studio/engine/models/file_paths.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
