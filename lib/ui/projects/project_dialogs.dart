import 'package:flutter/material.dart';

import '../../engine/projects/project.dart';
import '../../engine/projects/projects_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'project_colors.dart';

/// What the user typed in the new / rename project dialog.
typedef ProjectFormResult = ({String name, int colorIndex});

/// Asks for a project name (and, when [colorIndex] is given, its color).
/// Validation happens in the dialog, which stays open until the name is
/// acceptable. Returns null when cancelled.
Future<ProjectFormResult?> showProjectFormDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required List<Project> existing,
  String initialName = '',
  String? exceptId,
  int? colorIndex,
}) {
  return showDialog<ProjectFormResult>(
    context: context,
    builder: (_) => _ProjectFormDialog(
      title: title,
      confirmLabel: confirmLabel,
      existing: existing,
      initialName: initialName,
      exceptId: exceptId,
      initialColorIndex: colorIndex,
    ),
  );
}

/// Asks to confirm deleting [project] and everything in it.
Future<bool> confirmDeleteProject(BuildContext context, Project project) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete "${project.name}"?'),
      content: const Text(
        'This permanently deletes its environments, collections, flows and history. '
        'It cannot be undone.',
      ),
      actions: [
        TextButton(
          key: const Key('delete-project-cancel-button'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('delete-project-confirm-button'),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

String projectNameProblemText(ProjectNameProblem problem) => switch (problem) {
      ProjectNameProblem.empty => 'Give the project a name.',
      ProjectNameProblem.tooLong => 'Names are limited to $maxProjectNameLength characters.',
      ProjectNameProblem.duplicate => 'A project with that name already exists.',
    };

class _ProjectFormDialog extends StatefulWidget {
  const _ProjectFormDialog({
    required this.title,
    required this.confirmLabel,
    required this.existing,
    required this.initialName,
    required this.exceptId,
    required this.initialColorIndex,
  });

  final String title;
  final String confirmLabel;
  final List<Project> existing;
  final String initialName;
  final String? exceptId;
  final int? initialColorIndex;

  @override
  State<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<_ProjectFormDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialName);
  late int _colorIndex = widget.initialColorIndex ?? 0;
  ProjectNameProblem? _problem;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final problem = checkProjectName(_controller.text, widget.existing, exceptId: widget.exceptId);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.of(context).pop((name: _controller.text.trim(), colorIndex: _colorIndex));
  }

  @override
  Widget build(BuildContext context) {
    final problem = _problem;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('project-name-field'),
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Project name'),
              onChanged: (_) {
                if (_problem != null) setState(() => _problem = null);
              },
              onSubmitted: (_) => _submit(),
            ),
            if (problem != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  projectNameProblemText(problem),
                  key: const Key('project-name-error'),
                  style: AppTypography.bodySm.copyWith(color: AppColors.error),
                ),
              ),
            if (widget.initialColorIndex != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Color', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (var i = 0; i < projectColors.length; i++)
                    _Swatch(
                      index: i,
                      selected: i == _colorIndex,
                      onTap: () => setState(() => _colorIndex = i),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('project-dialog-cancel-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('project-dialog-confirm-button'),
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.index, required this.selected, required this.onTap});

  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      key: Key('project-color-$index'),
      onTap: onTap,
      radius: 18,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: projectColor(index),
          shape: BoxShape.circle,
          border: Border.all(color: selected ? AppColors.onSurface : Colors.transparent, width: 2),
        ),
        child: selected ? const Icon(Icons.check, size: 14, color: AppColors.onPrimary) : null,
      ),
    );
  }
}
