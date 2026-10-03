import 'package:api_flow_studio/engine/storage/json_store.dart';

import '../../integration_test/support/journey_harness.dart';

/// Keeps the data in memory: no window, no files, no real I/O, so the journeys
/// run fast anywhere. Persistence across a restart still works because the same
/// store object is reused.
class InMemoryHarness extends JourneyHarness {
  @override
  Future<JsonStore> newStore() async => JsonStore.inMemory();
}
