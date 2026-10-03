import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../environments/environments_provider.dart' show jsonStoreProvider;

/// Per-endpoint history, family-keyed by endpoint id. `send_provider.dart`
/// invalidates the relevant instance after every successful append so a
/// currently-open History tab picks up the new entry without a manual
/// refresh.
class HistoryNotifier extends FamilyAsyncNotifier<List<HistoryEntry>, String> {
  @override
  Future<List<HistoryEntry>> build(String endpointId) =>
      ref.watch(jsonStoreProvider).readHistory(endpointId);
}

final historyProvider =
    AsyncNotifierProvider.family<HistoryNotifier, List<HistoryEntry>, String>(
  HistoryNotifier.new,
);
