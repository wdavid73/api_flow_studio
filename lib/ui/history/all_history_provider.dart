import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../environments/environments_provider.dart';

/// Every stored history entry across all saved requests, newest first.
/// Invalidated by `SendNotifier` whenever a send is recorded.
final allHistoryProvider = FutureProvider<List<HistoryEntry>>(
  (ref) => ref.watch(jsonStoreProvider).readAllHistory(),
);
