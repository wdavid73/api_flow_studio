import 'dart:io';

import 'package:api_flow_studio/engine/storage/json_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'journey_harness.dart';

/// Keeps the data on a real temporary folder, so persistence goes through the
/// actual files. Each store gets its own folder, removed when the test ends.
class DiskHarness extends JourneyHarness {
  /// The folder of the most recently created store, for tests that inspect it.
  Directory? lastDirectory;

  @override
  Future<JsonStore> newStore() async {
    final dir = await Directory.systemTemp.createTemp('api_flow_journey_');
    lastDirectory = dir;
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    return JsonStore(directory: dir);
  }
}
