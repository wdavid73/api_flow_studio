import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/projects/project.dart';
import '../shell/app_toast.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'project_colors.dart';
import 'project_dialogs.dart';
import 'projects_provider.dart';

/// The header button that shows the active project (name and color) and opens a
/// menu to switch to another one.
class ProjectSwitcher extends ConsumerWidget {
  const ProjectSwitcher({super.key});

  // Menu values that are actions; anything else is a project id.
  static const _newProject = ':new';
  static const _renameProject = ':rename';
  static const _deleteProject = ':delete';

  Future<void> _onSelected(BuildContext context, WidgetRef ref, String value) async {
    final controller = ref.read(projectsProvider.notifier);
    final state = ref.read(projectsProvider);

    switch (value) {
      case _newProject:
        final result = await showProjectFormDialog(
          context,
          title: 'New project',
          confirmLabel: 'Create',
          existing: state.projects,
          colorIndex: nextProjectColorIndex(state.projects),
        );
        if (result == null) return;
        await controller.create(result.name, colorIndex: result.colorIndex);
        showToast(ref, 'Project "${result.name}" created');
      case _renameProject:
        final result = await showProjectFormDialog(
          context,
          title: 'Rename project',
          confirmLabel: 'Rename',
          existing: state.projects,
          initialName: state.active.name,
          exceptId: state.active.id,
        );
        if (result == null) return;
        await controller.rename(state.active.id, result.name);
        showToast(ref, 'Project renamed to "${result.name}"');
      case _deleteProject:
        if (!await confirmDeleteProject(context, state.active)) return;
        await controller.delete(state.active.id);
        showToast(ref, 'Project "${state.active.name}" deleted');
      default:
        if (value != state.active.id) await controller.switchTo(value);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectsProvider);
    final active = state.active;

    return PopupMenuButton<String>(
      key: const Key('project-switcher'),
      tooltip: 'Switch project',
      offset: const Offset(0, 40),
      color: AppColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      onSelected: (value) => _onSelected(context, ref, value),
      itemBuilder: (context) => [
        for (final project in state.projects)
          PopupMenuItem<String>(
            key: Key('project-option-${project.id}'),
            value: project.id,
            child: _ProjectRow(project: project, active: project.id == active.id),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          key: Key('new-project-button'),
          value: _newProject,
          child: _ActionRow(icon: Icons.add, label: 'New project…'),
        ),
        const PopupMenuItem<String>(
          key: Key('rename-project-button'),
          value: _renameProject,
          child: _ActionRow(icon: Icons.edit_outlined, label: 'Rename project…'),
        ),
        if (state.projects.length > 1)
          const PopupMenuItem<String>(
            key: Key('delete-project-button'),
            value: _deleteProject,
            child: _ActionRow(icon: Icons.delete_outline, label: 'Delete project…', danger: true),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(color: projectColor(active.colorIndex), dotKey: const Key('project-switcher-dot')),
            const SizedBox(width: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                active.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.expand_more, size: 18, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.active});

  final Project project;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Dot(color: projectColor(project.colorIndex)),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            project.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMd.copyWith(fontWeight: active ? FontWeight.w700 : FontWeight.w500),
          ),
        ),
        if (active) ...[
          const SizedBox(width: AppSpacing.md),
          const Icon(Icons.check, size: 16, color: AppColors.primary),
        ],
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, this.danger = false});

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: AppTypography.bodyMd.copyWith(color: danger ? AppColors.error : AppColors.onSurface)),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.dotKey});

  final Color color;
  final Key? dotKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: dotKey,
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
