import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late JsonStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('history_store_test_');
    store = JsonStore(directory: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  HistoryEntry entryFor(String endpointId, int i) => HistoryEntry(
        id: 'h-$i',
        endpointId: endpointId,
        timestamp: DateTime.utc(2026, 1, 1, 0, i),
        status: 200,
        elapsedMs: i,
      );

  test('readHistory is empty for an endpoint that has never been sent', () async {
    expect(await store.readHistory('e-1'), isEmpty);
  });

  test('appending trims to the last maxPerEndpoint entries, oldest evicted first', () async {
    for (var i = 0; i < 25; i++) {
      await store.appendHistoryEntry('e-1', entryFor('e-1', i), maxPerEndpoint: 20);
    }

    final history = await store.readHistory('e-1');
    expect(history, hasLength(20));
    // Entries 0-4 were evicted; 5-24 remain, in append order.
    expect(history.first.id, 'h-5');
    expect(history.last.id, 'h-24');
  });

  test('history for different endpoints does not cross-contaminate', () async {
    await store.appendHistoryEntry('e-1', entryFor('e-1', 0));
    await store.appendHistoryEntry('e-2', entryFor('e-2', 0));
    await store.appendHistoryEntry('e-2', entryFor('e-2', 1));

    expect(await store.readHistory('e-1'), hasLength(1));
    expect(await store.readHistory('e-2'), hasLength(2));
  });

  test('overlapping appends to the same endpoint are serialized, not racing', () async {
    final appends = [
      for (var i = 0; i < 10; i++) store.appendHistoryEntry('e-1', entryFor('e-1', i)),
    ];

    await Future.wait(appends);

    // The point isn't the final order -- it's that none of the 10
    // concurrent appends silently overwrote another's result.
    expect(await store.readHistory('e-1'), hasLength(10));
  });
}
