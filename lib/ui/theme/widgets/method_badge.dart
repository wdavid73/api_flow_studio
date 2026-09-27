import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

/// HTTP method badge, colored per DESIGN.md's "Method Badge System" table.
/// Unrecognized verbs (HEAD/OPTIONS/TRACE/...) fall back to a neutral slate.
class MethodBadge extends StatelessWidget {
  const MethodBadge({super.key, required this.method});

  final String method;

  static const Map<String, Color> _colorByMethod = {
    'GET': AppColors.methodGet,
    'POST': AppColors.methodPost,
    'PUT': AppColors.methodPut,
    'PATCH': AppColors.methodPatch,
    'DELETE': AppColors.methodDelete,
  };

  /// The badge color for a given HTTP verb, exposed so other widgets (e.g.
  /// the add-step picker's method filter chips) can match this badge's
  /// palette without duplicating the map.
  static Color colorForMethod(String method) => _colorByMethod[method.toUpperCase()] ?? AppColors.methodOther;

  Color get _color => colorForMethod(method);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        method.toUpperCase(),
        style: AppTypography.badgeMono.copyWith(color: _color),
      ),
    );
  }
}
