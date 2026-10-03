import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_typography.dart';

/// HTTP method label: colored monospace text without a fill, as in the
/// playground sidebar. Unrecognized verbs (HEAD/OPTIONS/TRACE/...) fall back
/// to the neutral outline color.
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
    return Text(
      method.toUpperCase(),
      style: AppTypography.badgeMono.copyWith(color: _color),
    );
  }
}
