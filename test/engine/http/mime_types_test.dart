import 'package:api_flow_studio/engine/http/mime_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('contentTypeForPath', () {
    test('knows the common extensions', () {
      const expected = {
        'a.png': 'image/png',
        'a.jpg': 'image/jpeg',
        'a.jpeg': 'image/jpeg',
        'a.gif': 'image/gif',
        'a.webp': 'image/webp',
        'a.svg': 'image/svg+xml',
        'a.pdf': 'application/pdf',
        'a.json': 'application/json',
        'a.txt': 'text/plain',
        'a.csv': 'text/csv',
        'a.xml': 'application/xml',
        'a.html': 'text/html',
        'a.zip': 'application/zip',
      };
      expected.forEach((path, type) => expect(contentTypeForPath(path), type, reason: path));
    });

    test('ignores the case of the extension', () {
      expect(contentTypeForPath('PHOTO.PNG'), 'image/png');
      expect(contentTypeForPath('Report.Pdf'), 'application/pdf');
    });

    test('uses the last extension of a name with several dots and looks only at the file name', () {
      expect(contentTypeForPath('/tmp/backup.tar.zip'), 'application/zip');
      expect(contentTypeForPath('/tmp/dir.png/readme'), 'application/octet-stream');
      expect(contentTypeForPath(r'C:\\data\\scan.JPG'), 'image/jpeg');
    });

    test('falls back to octet-stream for unknown, missing or empty extensions', () {
      for (final path in ['a.xyz', 'noextension', 'trailingdot.', '', '.hidden']) {
        expect(contentTypeForPath(path), 'application/octet-stream', reason: path);
      }
    });
  });
}
