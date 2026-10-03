import 'dart:convert';

import '../models/models.dart';

/// Value of the `format` field that marks a workspace file.
const String workspaceFormat = 'api-flow-studio-workspace';

/// The version of the format this app writes and the newest one it reads.
const int workspaceFormatVersion = 1;

/// Largest workspace text read (characters). A bigger file is refused before it
/// is parsed.
const int maxWorkspaceFileChars = 10 * 1024 * 1024;

enum WorkspaceFileProblem { tooLarge, notJson, notAWorkspace, newerVersion, invalid }

/// A file could not be read as a workspace; [message] says why in plain words.
class WorkspaceFileException implements Exception {
  const WorkspaceFileException(this.problem);

  final WorkspaceFileProblem problem;

  String get message => switch (problem) {
        WorkspaceFileProblem.tooLarge => 'That file is too large to be a workspace (the limit is 10 MB).',
        WorkspaceFileProblem.notJson => 'That file is not valid JSON.',
        WorkspaceFileProblem.notAWorkspace => 'That file is not an API Flow Studio workspace.',
        WorkspaceFileProblem.newerVersion =>
          'That workspace was made by a newer version of API Flow Studio. Update the app to open it.',
        WorkspaceFileProblem.invalid => 'That workspace file is damaged or incomplete.',
      };

  @override
  String toString() => 'WorkspaceFileException(${problem.name})';
}

/// A project as it travels in a file: its name and color and everything in it
/// that another person needs, and nothing personal (no history, no tokens, no
/// secret values).
class WorkspaceFile {
  const WorkspaceFile({
    required this.name,
    this.colorIndex = 0,
    this.environments = const [],
    this.groups = const [],
    this.endpoints = const [],
    this.flows = const [],
    this.hostNotes = const {},
    required this.exportedAt,
  });

  final String name;
  final int colorIndex;
  final List<Environment> environments;
  final List<Group> groups;
  final List<Endpoint> endpoints;
  final List<Flow> flows;
  final Map<String, String> hostNotes;
  final DateTime exportedAt;

  /// How many values the person who imports the file has to type in: secret
  /// variables and request credentials that came empty.
  int get secretsToFill {
    var count = 0;
    for (final env in environments) {
      count += env.variables.values.where((v) => v.secret && v.value.isEmpty).length;
    }
    for (final endpoint in endpoints) {
      count += switch (endpoint.authConfig) {
        AuthConfigBearer(:final token) => token.isEmpty ? 1 : 0,
        AuthConfigBasic(:final password) => password.isEmpty ? 1 : 0,
        _ => 0,
      };
    }
    return count;
  }

  Map<String, dynamic> toJson() => {
        'format': workspaceFormat,
        'version': workspaceFormatVersion,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
        'project': {'name': name, 'colorIndex': colorIndex},
        'environments': environments.map((e) => e.toJson()).toList(),
        'collections': {
          'groups': groups.map((g) => g.toJson()).toList(),
          'endpoints': endpoints.map((e) => e.toJson()).toList(),
        },
        'flows': flows.map((f) => f.toJson()).toList(),
        'hostNotes': hostNotes,
      };

  /// The file text, indented so it reads well in a diff.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Reads a workspace from its [text], or throws a [WorkspaceFileException].
  /// Unknown fields are ignored and missing sections are empty.
  factory WorkspaceFile.parse(String text) {
    if (text.length > maxWorkspaceFileChars) {
      throw const WorkspaceFileException(WorkspaceFileProblem.tooLarge);
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const WorkspaceFileException(WorkspaceFileProblem.notJson);
    }
    if (decoded is! Map<String, dynamic> || decoded['format'] != workspaceFormat) {
      throw const WorkspaceFileException(WorkspaceFileProblem.notAWorkspace);
    }

    final version = decoded['version'];
    if (version is! int || version < 1) throw const WorkspaceFileException(WorkspaceFileProblem.invalid);
    if (version > workspaceFormatVersion) throw const WorkspaceFileException(WorkspaceFileProblem.newerVersion);

    try {
      final project = decoded['project'] as Map<String, dynamic>;
      final name = (project['name'] as String).trim();
      if (name.isEmpty) throw const WorkspaceFileException(WorkspaceFileProblem.invalid);
      final collections = decoded['collections'] as Map<String, dynamic>? ?? const {};
      final exportedAt = decoded['exportedAt'] as String?;

      return WorkspaceFile(
        name: name,
        colorIndex: (project['colorIndex'] as int?) ?? 0,
        environments: _list(decoded['environments'], Environment.fromJson),
        groups: _list(collections['groups'], Group.fromJson),
        endpoints: _list(collections['endpoints'], Endpoint.fromJson),
        flows: _list(decoded['flows'], Flow.fromJson),
        hostNotes: {
          for (final e in ((decoded['hostNotes'] as Map<String, dynamic>?) ?? const {}).entries)
            if (e.value is String) e.key: e.value as String,
        },
        exportedAt: exportedAt == null ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true) : DateTime.parse(exportedAt),
      );
    } on WorkspaceFileException {
      rethrow;
    } catch (_) {
      // A wrong type, a missing required field, a bad date: one answer for all.
      throw const WorkspaceFileException(WorkspaceFileProblem.invalid);
    }
  }

  static List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) fromJson) =>
      value == null ? <T>[] : [for (final item in value as List) fromJson(item as Map<String, dynamic>)];
}

/// A file name for exporting [projectName]: the name with what a file name
/// cannot hold replaced, plus the workspace extension.
String workspaceFileName(String projectName) {
  final safe = projectName
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f\s]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return '${safe.isEmpty ? 'workspace' : safe}.workspace.json';
}
