import 'package:flutter/painting.dart';

import '../../engine/models/environment_kind.dart';
import '../../engine/models/models.dart';
import '../theme/app_colors.dart';

export '../../engine/models/environment_kind.dart' show isProductionEnvironment;

/// Dot color for [environment] at list position [index]: red for production,
/// otherwise cycling through the non-red palette.
Color environmentDotColorFor(Environment environment, int index) =>
    isProductionEnvironment(environment.name) ? AppColors.error : AppColors.environmentDotColor(index);
