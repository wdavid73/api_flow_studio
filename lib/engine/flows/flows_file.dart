import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../import/import_naming.dart';
import '../models/file_paths.dart';
import '../models/models.dart';
import '../workspace/export_workspace.dart' show withoutCredentials;

/// Value of the `format` field that marks a flows file.
const String flowsFileFormat = 'api-flow-studio-flows';

/// The version of the flows format this app writes and the newest one it reads.
const int flowsFileVersion = 1;

/// Largest flows text read (characters); a bigger file is refused before it is parsed.
const int maxFlowsFileChars = 10 * 1024 * 1024;

enum FlowsFileProblem { tooLarge, notJson, notAFlowsFile, newerVersion, invalid }

/// A file could not be read as a flows file; [message] says why in plain words.
class FlowsFileException implements Exception {
  const FlowsFileException(this.problem);

  final FlowsFileProblem problem;

  String get message => switch (problem) {
        FlowsFileProblem.tooLarge => 'That file is too large to be a flows file (the limit is 10 MB).',
        FlowsFileProblem.notJson => 'That file is not valid JSON.',
        FlowsFileProblem.notAFlowsFile => 'That file is not an API Flow Studio flows file.',
        FlowsFileProblem.newerVersion =>
          'That file was made by a newer version of API Flow Studio. Update the app to open it.',
        FlowsFileProblem.invalid => 'That flows file is damaged or incomplete.',
      };

  @override
  String toString() => 'FlowsFileException(${problem.name})';
}

/// Flows on their way between projects. A step only knows the id of its request, and
/// ids mean nothing in another project, so the file carries the requests the flows use
/// (and the folders that hold them) next to the flows.
///
/// Like a workspace file it holds nothing personal: literal credentials of a request's
/// authentication and the paths of its multipart files are left out.
class FlowsFile {
  const FlowsFile({
    this.flows = const [],
    this.groups = const [],
    this.endpoints = const [],
    required this.exportedAt,
  });

  final List<Flow> flows;
  final List<Group> groups;
  final List<Endpoint> endpoints;
  final DateTime exportedAt;

  Map<String, dynamic> toJson() => {
        'format': flowsFileFormat,
        'version': flowsFileVersion,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'flows': flows.map((f) => f.toJson()).toList(),
        'requests': {
          'groups': groups.map((g) => g.toJson()).toList(),
          'endpoints': endpoints.map((e) => e.toJson()).toList(),
        },
      };

  /// The file text, indented so it reads well in a diff.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Reads a flows file from [text], or throws a [FlowsFileException]. Unknown fields
  /// are ignored and missing sections are empty.
  factory FlowsFile.parse(String text) {
    if (text.length > maxFlowsFileChars) throw const FlowsFileException(FlowsFileProblem.tooLarge);

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FlowsFileException(FlowsFileProblem.notJson);
    }
    if (decoded is! Map<String, dynamic> || decoded['format'] != flowsFileFormat) {
      throw const FlowsFileException(FlowsFileProblem.notAFlowsFile);
    }

    final version = decoded['version'];
    if (version is! int || version < 1) throw const FlowsFileException(FlowsFileProblem.invalid);
    if (version > flowsFileVersion) throw const FlowsFileException(FlowsFileProblem.newerVersion);

    try {
      final requests = decoded['requests'] as Map<String, dynamic>? ?? const {};
      final exportedAt = decoded['exportedAt'] as String?;
      return FlowsFile(
        flows: _list(decoded['flows'], Flow.fromJson),
        groups: _list(requests['groups'], Group.fromJson),
        endpoints: _list(requests['endpoints'], Endpoint.fromJson),
        exportedAt: exportedAt == null ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true) : DateTime.parse(exportedAt),
      );
    } catch (_) {
      // A wrong type, a missing required field, a bad date: one answer for all.
      throw const FlowsFileException(FlowsFileProblem.invalid);
    }
  }

  static List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) fromJson) =>
      value == null ? <T>[] : [for (final item in value as List) fromJson(item as Map<String, dynamic>)];
}

/// A file name for exporting [count] flows: the name of the only one, or `flows`.
String flowsFileName(List<Flow> exported) {
  final base = exported.length == 1 ? exported.single.name : 'flows';
  final safe = base.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f\s]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  return '${safe.isEmpty ? 'flows' : safe}.flows.json';
}

/// The file for [flows]: each flow with the requests its steps use and the folders
/// that lead to them. A step whose request no longer exists is kept as it is.
FlowsFile buildFlowsFile(
  List<Flow> flows, {
  required List<Group> groups,
  required List<Endpoint> endpoints,
  DateTime Function()? now,
}) {
  final byId = {for (final e in endpoints) e.id: e};
  final used = <String>{for (final f in flows) for (final s in f.steps) s.endpointId};
  final usedEndpoints = [for (final e in endpoints) if (used.contains(e.id)) e];

  final groupsById = {for (final g in groups) g.id: g};
  final neededGroups = <String>{};
  for (final endpoint in usedEndpoints) {
    for (var id = byId[endpoint.id]?.groupId; id != null && neededGroups.add(id); id = groupsById[id]?.parentGroupId) {}
  }

  return FlowsFile(
    flows: flows,
    groups: [for (final g in groups) if (neededGroups.contains(g.id)) g],
    endpoints: [for (final e in usedEndpoints) withoutFilePaths(withoutCredentials(e))],
    exportedAt: (now ?? DateTime.now)(),
  );
}

const String _orphanFolderId = '__imported-flows__';

/// What importing some flows into a project adds, ready to be saved.
class FlowsImportPlan {
  const FlowsImportPlan({
    required this.flows,
    required this.newGroups,
    required this.newEndpoints,
    required this.reusedEndpoints,
    required this.missingSteps,
    required this.filesToChoose,
  });

  /// The flows to add, with new ids and steps pointing at requests of the project.
  final List<Flow> flows;

  /// Folders and requests the project did not have; they keep the folder tree they came in.
  final List<Group> newGroups;
  final List<Endpoint> newEndpoints;

  /// Requests of the file the project already had (same method and URL): the flows use those.
  final int reusedEndpoints;

  /// Steps whose request is neither in the file nor could be found.
  final int missingSteps;

  /// Multipart file fields of the added requests that need a file chosen.
  final int filesToChoose;
}

/// Works out how to bring [selected] flows of [file] into a project that has
/// [existingGroups], [existingEndpoints] and [existingFlows].
///
/// A request of the file that the project already has (same method and URL) is not
/// copied: the step points at the existing one. Any other request is added, in
/// folders found by name along the same path or created. Flows get new ids and a
/// number in their name when it is taken. Nothing that exists is changed.
FlowsImportPlan planFlowsImport(
  FlowsFile file, {
  required Set<String> selected,
  required List<Group> existingGroups,
  required List<Endpoint> existingEndpoints,
  required List<Flow> existingFlows,
}) {
  const uuid = Uuid();
  final chosen = [for (final f in file.flows) if (selected.contains(f.id)) f];

  String signature(Endpoint e) => '${e.method.toUpperCase()} ${e.url.trim()}';
  final existingBySignature = <String, Endpoint>{};
  for (final e in existingEndpoints) {
    existingBySignature.putIfAbsent(signature(e), () => e);
  }
  final fileEndpoints = {for (final e in file.endpoints) e.id: e};
  final fileGroups = {for (final g in file.groups) g.id: g};

  final groups = [...existingGroups];
  final newGroups = <Group>[];
  final folderIds = <String, String>{}; // file group id -> id in the project

  String? folderFor(String? fileGroupId) {
    if (fileGroupId == null) return null;
    final cached = folderIds[fileGroupId];
    if (cached != null) return cached;
    final group = fileGroups[fileGroupId];
    if (group == null) return null;

    final parent = group.parentGroupId == null ? null : folderFor(group.parentGroupId);
    final name = group.name.trim().toLowerCase();
    Group? found;
    for (final g in groups) {
      if (g.parentGroupId == parent && g.name.trim().toLowerCase() == name) {
        found = g;
        break;
      }
    }
    if (found == null) {
      final order = groups.where((g) => g.parentGroupId == parent).length;
      found = Group(id: uuid.v4(), name: group.name, parentGroupId: parent, order: order);
      groups.add(found);
      newGroups.add(found);
    }
    return folderIds[fileGroupId] = found.id;
  }

  final newEndpoints = <Endpoint>[];
  final resolved = <String, String>{}; // file endpoint id -> id in the project
  var reused = 0;

  String? endpointFor(String fileEndpointId) {
    final cached = resolved[fileEndpointId];
    if (cached != null) return cached;
    final endpoint = fileEndpoints[fileEndpointId];
    if (endpoint == null) return null;

    final existing = existingBySignature[signature(endpoint)];
    if (existing != null) {
      reused++;
      return resolved[fileEndpointId] = existing.id;
    }

    // A request whose folder is not in the file lands in an "Imported flows" folder.
    fileGroups.putIfAbsent(_orphanFolderId, () => const Group(id: _orphanFolderId, name: 'Imported flows'));
    final groupId = folderFor(fileGroups.containsKey(endpoint.groupId) ? endpoint.groupId : _orphanFolderId);
    final added = withoutFilePaths(endpoint).copyWith(id: uuid.v4(), groupId: groupId ?? '');
    newEndpoints.add(added);
    existingBySignature[signature(added)] = added;
    return resolved[fileEndpointId] = added.id;
  }

  final takenNames = [for (final f in existingFlows) f.name];
  var missing = 0;
  final flows = <Flow>[];
  for (final flow in chosen) {
    final steps = <FlowStep>[];
    for (final step in flow.steps) {
      final id = endpointFor(step.endpointId);
      if (id == null) missing++;
      steps.add(step.copyWith(endpointId: id ?? step.endpointId));
    }
    final name = uniqueName(flow.name, takenNames);
    takenNames.add(name);
    flows.add(flow.copyWith(id: uuid.v4(), name: name, steps: steps));
  }

  return FlowsImportPlan(
    flows: flows,
    newGroups: newGroups,
    newEndpoints: newEndpoints,
    reusedEndpoints: reused,
    missingSteps: missing,
    filesToChoose: filePathsToFill(newEndpoints),
  );
}
