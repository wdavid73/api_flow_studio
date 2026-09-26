import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Reads and writes the app's collections/environments/flows as plain JSON
/// files on disk, under the OS standard app-data folder by default (inject
/// [directory] to point at a different location, e.g. a temp dir in tests).
///
/// Writes are atomic (write to `<file>.tmp`, then rename over the target)
/// so a crash mid-write can never leave a half-written file in place.
/// Reads that hit invalid JSON back the corrupt file up as
/// `<file>.corrupt-<timestamp>` and fall back to an empty default rather
/// than throwing.
class JsonStore {
  JsonStore({Directory? directory}) : _directoryOverride = directory;

  final Directory? _directoryOverride;

  /// Serializes writes per filename: without this, two overlapping writes
  /// to the same file (e.g. two keystrokes' worth of state changes firing
  /// before the first write finishes) can race on the same `.tmp` path and
  /// make one rename fail with "file not found" -- caught by a real test
  /// here, not a hypothetical.
  final Map<String, Future<void>> _writeQueues = {};

  Future<Directory> _directory() async {
    final dir = _directoryOverride ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}api_flow_studio',
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

  Future<void> _writeAtomic(String filename, Object jsonValue) {
    final previous = _writeQueues[filename] ?? Future<void>.value();
    final next = previous.then((_) => _writeAtomicUnqueued(filename, jsonValue));
    // Swallow the error here so it doesn't become an unhandled rejection
    // sitting in the queue chain -- the real caller still awaits `next`
    // directly below and sees the exception there.
    _writeQueues[filename] = next.catchError((_) {});
    return next;
  }

  Future<void> _writeAtomicUnqueued(String filename, Object jsonValue) async {
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

  Future<List<Flow>> readFlows() => _readOrDefault(
        'flows.json',
        (decoded) =>
            (decoded as List).map((e) => Flow.fromJson(e as Map<String, dynamic>)).toList(),
        <Flow>[],
      );

  Future<void> writeFlows(List<Flow> flows) =>
      _writeAtomic('flows.json', flows.map((f) => f.toJson()).toList());
}
