import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../environments/environments_provider.dart';

/// The note typed for each host (base) name, backed by `host_notes.json`.
/// Edits update the state at once and are written in order, one at a time.
class HostNotesNotifier extends AsyncNotifier<Map<String, String>> {
  Future<void> _writes = Future.value();

  @override
  Future<Map<String, String>> build() => ref.watch(jsonStoreProvider).readHostNotes();

  /// Sets the note of [hostName]; a blank [text] removes it.
  Future<void> setNote(String hostName, String text) {
    final next = {...(state.value ?? const <String, String>{})};
    if (text.trim().isEmpty) {
      next.remove(hostName);
    } else {
      next[hostName] = text;
    }
    state = AsyncData(next);

    final store = ref.read(jsonStoreProvider);
    return _writes = _writes.then((_) => store.writeHostNotes(next));
  }
}

final hostNotesProvider = AsyncNotifierProvider<HostNotesNotifier, Map<String, String>>(HostNotesNotifier.new);
