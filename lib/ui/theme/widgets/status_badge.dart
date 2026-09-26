import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

/// HTTP response status code badge, colored by status band (2xx/3xx/4xx/5xx)
/// per DESIGN.md's "Status Code Badges" component spec.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.statusCode});

  final int statusCode;

  Color get _color {
    if (statusCode >= 200 && statusCode < 300) return AppColors.status2xx;
    if (statusCode >= 300 && statusCode < 400) return AppColors.status3xx;
    if (statusCode >= 400 && statusCode < 500) return AppColors.status4xx;
    return AppColors.status5xx;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '$statusCode',
        style: AppTypography.codeMd.copyWith(color: _color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
