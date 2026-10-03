import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/projects/project.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'project_colors.dart';
import 'projects_provider.dart';

/// The header button that shows the active project (name and color) and opens a
/// menu to switch to another one.
class ProjectSwitcher extends ConsumerWidget {
  const ProjectSwitcher({super.key});

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
      onSelected: (id) {
        if (id != active.id) ref.read(projectsProvider.notifier).switchTo(id);
      },
      itemBuilder: (context) => [
        for (final project in state.projects)
          PopupMenuItem<String>(
            key: Key('project-option-${project.id}'),
            value: project.id,
            child: _ProjectRow(project: project, active: project.id == active.id),
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
