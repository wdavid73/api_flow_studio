import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

/// Pill-shaped `{{variable}}` token chip. Accent-tinted when [resolved] against the
/// active environment, warning-tinted when it isn't.
class VariableChip extends StatelessWidget {
  const VariableChip({super.key, required this.name, required this.resolved});

  final String name;
  final bool resolved;

  @override
  Widget build(BuildContext context) {
    final color = resolved ? AppColors.variableResolvedText : AppColors.variableUnresolvedText;
    final background = resolved ? AppColors.variableResolvedBg : AppColors.variableUnresolvedBg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: resolved ? Border.all(color: AppColors.variableResolvedBorder) : null,
      ),
      child: Text('{{$name}}', style: AppTypography.codeSm.copyWith(color: color)),
    );
  }
}
