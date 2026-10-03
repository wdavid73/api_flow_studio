import 'dart:convert';
import 'dart:io';

import '../models/models.dart';

/// Reads and writes the app's collections/environments/flows as plain JSON
/// files on disk, under a folder next to the running executable by default
/// (inject [directory] to point at a different location, e.g. a temp dir in
/// tests) -- this keeps the app portable: copy the build output folder
/// anywhere (a USB drive, a zip to share) and its data travels with it,
/// rather than being tied to the installing machine's per-user profile.
///
/// Writes are atomic (write to `<file>.tmp`, then rename over the target)
/// so a crash mid-write can never leave a half-written file in place.
/// Reads that hit invalid JSON back the corrupt file up as
/// `<file>.corrupt-<timestamp>` and fall back to an empty default rather
/// than throwing.
///
/// On the web there is no filesystem (`Platform.resolvedExecutable` throws),
/// so the default store keeps everything in memory for the session instead;
/// [JsonStore.inMemory] gives the same backend explicitly (used by tests).
class JsonStore {
  JsonStore({Directory? directory})
      : _directoryOverride = directory,
        _memory = directory == null && _isWeb ? {} : null;

  JsonStore.inMemory()
      : _directoryOverride = null,
        _memory = {};

  /// `true` when compiled to JavaScript (a JS `0.0` is identical to `0`).
  static const bool _isWeb = identical(0, 0.0);

  final Directory? _directoryOverride;

  /// Filename -> raw JSON when running without a filesystem, otherwise null.
  final Map<String, String>? _memory;

  /// Serializes operations per filename: without this, two overlapping
  /// writes to the same file (e.g. two keystrokes' worth of state changes
  /// firing before the first write finishes) can race on the same `.tmp`
  /// path and make one rename fail with "file not found" -- caught by a
  /// real test here, not a hypothetical. Read-modify-write helpers like
  /// [appendHistoryEntry] chain onto the same per-filename queue so a
  /// "read old, append, write" cycle can't interleave with a sibling call
  /// and silently drop one of the two appends.
  final Map<String, Future<void>> _queues = {};

  Future<T> _serialized<T>(String filename, Future<T> Function() action) {
    final previous = _queues[filename] ?? Future<void>.value();
    final result = previous.then((_) => action());
    _queues[filename] = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Directory> _directory() async {
    final dir = _directoryOverride ??
        Directory(
          '${File(Platform.resolvedExecutable).parent.path}'
          '${Platform.pathSeparator}api_flow_studio_data',
        );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _file(String filename) async {
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}$filename');
  }

  Future<void> _writeAtomic(String filename, Object jsonValue) =>
      _serialized(filename, () => _writeAtomicUnqueued(filename, jsonValue));

  Future<void> _writeAtomicUnqueued(String filename, Object jsonValue) async {
    final memory = _memory;
    if (memory != null) {
      memory[filename] = jsonEncode(jsonValue);
      return;
    }
    final target = await _file(filename);
    // Unique per write, not a fixed `<file>.tmp` -- avoids two writes ever
    // colliding on the same temp path even if queueing above had a bug.
    final tmp = File('${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}');
    await tmp.writeAsString(jsonEncode(jsonValue), flush: true);

    // On Windows, renaming over an existing file can transiently fail with
    // a sharing violation (errno 32) if something else -- most often
    // antivirus/Windows Search briefly scanning the just-written file --
    // still has a handle open. That handle is normally released within
    // milliseconds, so a short bounded retry is the standard mitigation
    // rather than a real correctness problem.
    const maxAttempts = 5;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await tmp.rename(target.path);
        return;
      } on FileSystemException {
        if (attempt == maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 20 * attempt));
      }
    }
  }

  Future<T> _readOrDefault<T>(String filename, T Function(dynamic decoded) parse, T fallback) async {
    final memory = _memory;
    if (memory != null) {
      final stored = memory[filename];
      return stored == null ? fallback : parse(jsonDecode(stored));
    }
    final file = await _file(filename);
    if (!await file.exists()) return fallback;

    final raw = await file.readAsString();
    try {
      return parse(jsonDecode(raw));
    } catch (_) {
      final backup = File('${file.path}.corrupt-${DateTime.now().millisecondsSinceEpoch}');
      await file.copy(backup.path);
      return fallback;
    }
  }

  Future<List<Environment>> readEnvironments() => _readOrDefault(
        'environments.json',
        (decoded) => (decoded as List)
            .map((e) => Environment.fromJson(e as Map<String, dynamic>))
            .toList(),
        <Environment>[],
      );

  Future<void> writeEnvironments(List<Environment> environments) =>
      _writeAtomic('environments.json', environments.map((e) => e.toJson()).toList());

  Future<String?> readActiveEnvironmentId() => _readOrDefault(
        'settings.json',
        (decoded) => (decoded as Map<String, dynamic>)['activeEnvironmentId'] as String?,
        null,
      );

  Future<void> writeActiveEnvironmentId(String? id) =>
      _writeAtomic('settings.json', {'activeEnvironmentId': id});

  Future<({List<Group> groups, List<Endpoint> endpoints})> readCollections() => _readOrDefault(
        'collections.json',
        (decoded) {
          final map = decoded as Map<String, dynamic>;
          return (
            groups: ((map['groups'] as List?) ?? const [])
                .map((e) => Group.fromJson(e as Map<String, dynamic>))
                .toList(),
            endpoints: ((map['endpoints'] as List?) ?? const [])
                .map((e) => Endpoint.fromJson(e as Map<String, dynamic>))
                .toList(),
          );
        },
        (groups: <Group>[], endpoints: <Endpoint>[]),
      );

  Future<void> writeCollections({
    required List<Group> groups,
    required List<Endpoint> endpoints,
  }) =>
      _writeAtomic('collections.json', {
        'groups': groups.map((g) => g.toJson()).toList(),
        'endpoints': endpoints.map((e) => e.toJson()).toList(),
      });

  /// The note typed for each host (base) name, from `host_notes.json`. Entries
  /// whose value is not a string are ignored.
  Future<Map<String, String>> readHostNotes() => _readOrDefault(
        'host_notes.json',
        (decoded) => {
          for (final entry in (decoded as Map<String, dynamic>).entries)
            if (entry.value is String) entry.key: entry.value as String,
        },
        <String, String>{},
      );

  /// Replaces the stored host notes. Blank notes are dropped.
  Future<void> writeHostNotes(Map<String, String> notes) => _writeAtomic('host_notes.json', {
        for (final entry in notes.entries)
          if (entry.value.trim().isNotEmpty) entry.key: entry.value,
      });

  Future<List<Flow>> readFlows() => _readOrDefault(
        'flows.json',
        (decoded) =>
            (decoded as List).map((e) => Flow.fromJson(e as Map<String, dynamic>)).toList(),
        <Flow>[],
      );

  Future<void> writeFlows(List<Flow> flows) =>
      _writeAtomic('flows.json', flows.map((f) => f.toJson()).toList());

  Future<Map<String, List<HistoryEntry>>> _readAllHistory() => _readOrDefault(
        'history.json',
        (decoded) => {
          for (final entry in (decoded as Map<String, dynamic>).entries)
            entry.key: (entry.value as List)
                .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
                .toList(),
        },
        <String, List<HistoryEntry>>{},
      );

  /// Every stored history entry across all endpoints, newest first.
  Future<List<HistoryEntry>> readAllHistory() async {
    final all = await _readAllHistory();
    return [for (final entries in all.values) ...entries]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<List<HistoryEntry>> readHistory(String endpointId) async =>
      (await _readAllHistory())[endpointId] ?? const [];

  /// Appends [entry] to [endpointId]'s history, trimming to the last
  /// [maxPerEndpoint] (oldest evicted first). The read-modify-write cycle
  /// runs inside [_serialized] on `history.json` -- two appends fired close
  /// together (e.g. sending the same request twice in a row) must not both
  /// read the same pre-append list and race to overwrite each other.
  Future<void> appendHistoryEntry(
    String endpointId,
    HistoryEntry entry, {
    int maxPerEndpoint = 20,
  }) =>
      _serialized('history.json', () async {
        final all = await _readAllHistory();
        final current = all[endpointId] ?? const <HistoryEntry>[];
        final next = [...current, entry];
        final trimmed =
            next.length > maxPerEndpoint ? next.sublist(next.length - maxPerEndpoint) : next;
        all[endpointId] = trimmed;
        await _writeAtomicUnqueued('history.json', {
          for (final e in all.entries) e.key: e.value.map((h) => h.toJson()).toList(),
        });
      });
}
