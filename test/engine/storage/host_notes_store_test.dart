import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late JsonStore disk;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('host_notes_store_test_');
    disk = JsonStore(directory: dir);
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  for (final kind in ['disk', 'memory']) {
    group(kind, () {
      JsonStore store() => kind == 'disk' ? disk : JsonStore.inMemory();

      test('reads an empty map when nothing was ever written', () async {
        expect(await store().readHostNotes(), isEmpty);
      });

      test('writes and reads back the notes', () async {
        final s = store();

        await s.writeHostNotes({'AUTH': 'Identity', 'MARKET': 'Vouchers'});

        expect(await s.readHostNotes(), {'AUTH': 'Identity', 'MARKET': 'Vouchers'});
      });

      test('blank notes are not stored', () async {
        final s = store();

        await s.writeHostNotes({'AUTH': 'Identity', 'EMPTY': '', 'SPACES': '   '});

        expect(await s.readHostNotes(), {'AUTH': 'Identity'});
      });

      test('a later write replaces the previous notes', () async {
        final s = store();
        await s.writeHostNotes({'AUTH': 'one', 'OLD': 'gone'});

        await s.writeHostNotes({'AUTH': 'two'});

        expect(await s.readHostNotes(), {'AUTH': 'two'});
      });

      test('writing notes does not touch the environments', () async {
        final s = store();
        await s.writeEnvironments([const Environment(id: 'dev', name: 'Dev')]);

        await s.writeHostNotes({'AUTH': 'Identity'});

        expect((await s.readEnvironments()).single.name, 'Dev');
      });
    });
  }

  test('notes live in their own host_notes.json and leave the other files alone', () async {
    await disk.writeEnvironments([const Environment(id: 'dev', name: 'Dev')]);
    final before = File('${dir.path}/environments.json').readAsStringSync();

    await disk.writeHostNotes({'AUTH': 'Identity'});

    expect(File('${dir.path}/host_notes.json').existsSync(), isTrue);
    expect(File('${dir.path}/environments.json').readAsStringSync(), before);
  });

  test('a corrupt host_notes.json is backed up and reads as empty', () async {
    File('${dir.path}/host_notes.json').writeAsStringSync('this is not json');

    expect(await disk.readHostNotes(), isEmpty);

    final backups = dir.listSync().whereType<File>().where((f) => f.path.contains('host_notes.json.corrupt-'));
    expect(backups, hasLength(1));
  });

  test('entries whose value is not a string are ignored', () async {
    File('${dir.path}/host_notes.json').writeAsStringSync('{"AUTH":"ok","BAD":42,"NULL":null}');

    expect(await disk.readHostNotes(), {'AUTH': 'ok'});
  });
}
