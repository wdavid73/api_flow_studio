import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Outlined, transparent header button (the playground "ghost" button).
/// Other modules put these in [AppHeader]'s actions zone so every header
/// action looks the same.
class HeaderGhostButton extends StatelessWidget {
  const HeaderGhostButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.field),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Text(label, style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface)),
      ),
    );
  }
}
