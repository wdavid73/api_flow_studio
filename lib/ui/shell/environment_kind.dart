import 'package:flutter/painting.dart';

import '../../engine/models/models.dart';
import '../theme/app_colors.dart';

/// True when [name] denotes a production environment (case-insensitive,
/// surrounding whitespace ignored). Detection is by name so the persisted
/// environment model doesn't need a flag.
bool isProductionEnvironment(String name) {
  const names = {'prod', 'production', 'prd'};
  return names.contains(name.trim().toLowerCase());
}

/// Dot color for [environment] at list position [index]: red for production,
/// otherwise cycling through the non-red palette.
Color environmentDotColorFor(Environment environment, int index) =>
    isProductionEnvironment(environment.name) ? AppColors.error : AppColors.environmentDotColor(index);
