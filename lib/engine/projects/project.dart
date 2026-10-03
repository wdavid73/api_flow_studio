import 'package:freezed_annotation/freezed_annotation.dart';

part 'project.freezed.dart';
part 'project.g.dart';

/// One isolated set of environments, collections, flows, history and host
/// notes (for example "commodo" for work, "fin_track_pro" for personal).
@freezed
class Project with _$Project {
  const factory Project({
    required String id,
    required String name,

    /// Which accent color the project shows in the UI (an index into the
    /// palette, wrapped by the UI).
    @Default(0) int colorIndex,
    required DateTime createdAt,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);
}

/// What `projects.json` holds: every project and which one is active.
class ProjectIndex {
  const ProjectIndex({this.projects = const [], this.activeProjectId});

  final List<Project> projects;
  final String? activeProjectId;

  factory ProjectIndex.fromJson(Map<String, dynamic> json) => ProjectIndex(
        projects: (json['projects'] as List)
            .map((e) => Project.fromJson(e as Map<String, dynamic>))
            .toList(),
        activeProjectId: json['activeProjectId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'activeProjectId': activeProjectId,
        'projects': projects.map((p) => p.toJson()).toList(),
      };
}
