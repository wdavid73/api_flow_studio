import 'dart:convert';
import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/history_limits.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('truncateToBytes', () {
    test('a short text is returned as it is', () {
      final result = truncateToBytes('hello', 100);

      expect(result.text, 'hello');
      expect(result.truncated, isFalse);
    });

    test('a text of exactly the limit is not truncated', () {
      final result = truncateToBytes('a' * 100, 100);

      expect(result.truncated, isFalse);
      expect(result.text, hasLength(100));
    });

    test('a longer text is cut to the limit and flagged', () {
      final result = truncateToBytes('a' * 300, 100);

      expect(result.text, hasLength(100));
      expect(result.truncated, isTrue);
    });

    test('it never splits a multi-byte character', () {
      // 'é' is 2 bytes: a limit of 5 bytes fits two of them and cannot hold a third.
      final result = truncateToBytes('éééé', 5);

      expect(result.text, 'éé');
      expect(utf8.encode(result.text).length, lessThanOrEqualTo(5));
      expect(result.truncated, isTrue);
    });

    test('it never splits a surrogate pair', () {
      // Each emoji is 4 bytes in UTF-8 and two UTF-16 code units.
      final result = truncateToBytes('😀' * 10, 10);

      expect(result.text, '😀😀');
      expect(result.text.contains('�'), isFalse);
      final units = result.text.codeUnits;
      for (var i = 0; i < units.length; i++) {
        final isHigh = units[i] >= 0xD800 && units[i] <= 0xDBFF;
        final isLow = units[i] >= 0xDC00 && units[i] <= 0xDFFF;
        if (isHigh) {
          // A high surrogate must be followed by its low one.
          expect(i + 1 < units.length && units[i + 1] >= 0xDC00 && units[i + 1] <= 0xDFFF, isTrue);
          i++;
        } else {
          expect(isLow, isFalse, reason: 'lone low surrogate at $i');
        }
      }
      expect(utf8.encode(result.text).length, lessThanOrEqualTo(10));
    });

    test('a limit smaller than the first character yields an empty text', () {
      final result = truncateToBytes('😀', 2);

      expect(result.text, isEmpty);
      expect(result.truncated, isTrue);
    });
  });

  group('storing a history entry', () {
    late Directory dir;
    late JsonStore store;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('history_limits_');
      store = JsonStore(directory: dir);
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
    });

    HistoryEntry entry(String endpointId, int i, {String? body, DateTime? at}) => HistoryEntry(
          id: 'h-$endpointId-$i',
          endpointId: endpointId,
          timestamp: at ?? DateTime.utc(2026, 1, 1).add(Duration(minutes: i)),
          status: 200,
          body: body,
        );

    test('a body of 300 KB is stored within the limit and flagged as truncated', () async {
      await store.appendHistoryEntry('e1', entry('e1', 1, body: 'x' * (300 * 1024)));

      final stored = (await store.readHistory('e1')).single;

      expect(utf8.encode(stored.body!).length, lessThanOrEqualTo(maxHistoryBodyBytes));
      expect(maxHistoryBodyBytes, 100 * 1024);
      expect(stored.truncated, isTrue);
    });

    test('a small body is kept whole and not flagged', () async {
      await store.appendHistoryEntry('e1', entry('e1', 1, body: '{"ok":true}'));

      final stored = (await store.readHistory('e1')).single;

      expect(stored.body, '{"ok":true}');
      expect(stored.truncated, isFalse);
    });

    test('an entry with no body (a failed send) is fine', () async {
      await store.appendHistoryEntry('e1', entry('e1', 1));

      expect((await store.readHistory('e1')).single.body, isNull);
    });

    test('the project keeps at most 500 entries, dropping the oldest across all requests', () async {
      // 30 requests x 20 sends = 600 entries, within the per-request limit of 20.
      var minute = 0;
      for (var round = 0; round < 20; round++) {
        for (var e = 0; e < 30; e++) {
          await store.appendHistoryEntry('e$e', entry('e$e', minute++));
        }
      }

      final all = await store.readAllHistory();

      expect(all, hasLength(maxHistoryEntriesPerProject));
      expect(maxHistoryEntriesPerProject, 500);
      expect(all.first.timestamp, DateTime.utc(2026, 1, 1).add(const Duration(minutes: 599)));
      expect(all.last.timestamp, DateTime.utc(2026, 1, 1).add(const Duration(minutes: 100)));
    });

    test('the limit per request still applies', () async {
      for (var i = 0; i < 25; i++) {
        await store.appendHistoryEntry('e1', entry('e1', i));
      }

      expect(await store.readHistory('e1'), hasLength(20));
    });

    test('an old history file with no flag and too many or too big entries is trimmed when read', () async {
      final entries = <String, dynamic>{
        for (var e = 0; e < 30; e++)
          'e$e': [
            for (var i = 0; i < 20; i++)
              {
                'id': 'h-$e-$i',
                'endpointId': 'e$e',
                'timestamp': DateTime.utc(2026, 1, 1).add(Duration(minutes: i * 30 + e)).toIso8601String(),
                'status': 200,
                'headers': <String, String>{},
                'body': 'y' * (150 * 1024),
                'elapsedMs': 1,
              },
          ],
      };
      await File('${dir.path}/history.json').writeAsString(jsonEncode(entries));

      final all = await store.readAllHistory();

      expect(all, hasLength(500));
      expect(all.every((h) => utf8.encode(h.body!).length <= maxHistoryBodyBytes), isTrue);
      expect(all.every((h) => h.truncated), isTrue);
      // The newest are the ones kept.
      expect(all.first.timestamp.isAfter(all.last.timestamp), isTrue);
    });

    test('history written before the flag existed loads, not flagged', () async {
      await File('${dir.path}/history.json').writeAsString(jsonEncode({
        'e1': [
          {
            'id': 'h1',
            'endpointId': 'e1',
            'timestamp': '2026-01-01T00:00:00.000Z',
            'status': 200,
            'headers': <String, String>{},
            'body': '{}',
            'elapsedMs': 1,
          },
        ],
      }));

      final stored = (await store.readHistory('e1')).single;

      expect(stored.truncated, isFalse);
      expect(stored.body, '{}');
    });
  });
}
