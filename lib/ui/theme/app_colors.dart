import 'package:flutter/material.dart';

/// Design tokens copied 1:1 from `design/api_flow_studio/DESIGN.md`'s YAML
/// frontmatter (the Material 3 role palette actually wired into the
/// exported `screen.png` references -- see Architecture Decision #1 in
/// tasks/plan.md for why the frontmatter, not the prose "Colors" section,
/// is the source of truth for these).
class AppColors {
  const AppColors._();

  static const Color surface = Color(0xFF111319);
  static const Color surfaceDim = Color(0xFF111319);
  static const Color surfaceBright = Color(0xFF373940);
  static const Color surfaceContainerLowest = Color(0xFF0C0E14);
  static const Color surfaceContainerLow = Color(0xFF191B22);
  static const Color surfaceContainer = Color(0xFF1E1F26);
  static const Color surfaceContainerHigh = Color(0xFF282A30);
  static const Color surfaceContainerHighest = Color(0xFF33343B);
  static const Color onSurface = Color(0xFFE2E2EB);
  static const Color onSurfaceVariant = Color(0xFFC7C4D7);
  static const Color inverseSurface = Color(0xFFE2E2EB);
  static const Color inverseOnSurface = Color(0xFF2E3037);
  static const Color outline = Color(0xFF908FA0);
  static const Color outlineVariant = Color(0xFF464554);
  static const Color surfaceTint = Color(0xFFC0C1FF);

  static const Color primary = Color(0xFFC0C1FF);
  static const Color onPrimary = Color(0xFF1000A9);
  static const Color primaryContainer = Color(0xFF8083FF);
  static const Color onPrimaryContainer = Color(0xFF0D0096);
  static const Color inversePrimary = Color(0xFF494BD6);

  static const Color secondary = Color(0xFF4CD7F6);
  static const Color onSecondary = Color(0xFF003640);
  static const Color secondaryContainer = Color(0xFF03B5D3);
  static const Color onSecondaryContainer = Color(0xFF00424E);

  static const Color tertiary = Color(0xFF4EDEA3);
  static const Color onTertiary = Color(0xFF003824);
  static const Color tertiaryContainer = Color(0xFF00885D);
  static const Color onTertiaryContainer = Color(0xFF000703);

  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  static const Color background = Color(0xFF111319);
  static const Color onBackground = Color(0xFFE2E2EB);
  static const Color surfaceVariant = Color(0xFF33343B);

  // -- Semantic extension: layered on top of the M3 roles above, not part
  // of them. Sourced from DESIGN.md's prose "Method Badge System" /
  // "Status Code Badges" / "Variable Chips" component sections, which give
  // explicit hex values the frontmatter doesn't cover.

  static const Color methodGet = Color(0xFF3B82F6);
  static const Color methodPost = Color(0xFF10B981);
  static const Color methodPut = Color(0xFFF97316);
  static const Color methodPatch = Color(0xFFEAB308);
  static const Color methodDelete = Color(0xFFEF4444);
  static const Color methodOther = Color(0xFF94A3B8);

  static const Color status2xx = Color(0xFF10B981);
  static const Color status3xx = Color(0xFF3B82F6);
  static const Color status4xx = Color(0xFFF97316);
  static const Color status5xx = Color(0xFFEF4444);

  static const Color variableResolvedText = Color(0xFF06B6D4);
  static const Color variableResolvedBg = Color(0x1F06B6D4); // ~12% alpha
  static const Color variableResolvedBorder = Color(0x4706B6D4); // ~28% alpha
  static const Color variableUnresolvedText = Color(0xFFF59E0B);
  static const Color variableUnresolvedBg = Color(0x26F59E0B); // ~15% alpha

  static const List<Color> environmentDotPalette = [tertiary, secondary, error];

  static Color environmentDotColor(int index) =>
      environmentDotPalette[index % environmentDotPalette.length];

  // Sidebar top-level folder icons cycle through a different palette than
  // environments (design/*/code.html shows folders in secondary/primary/
  // tertiary, not the tertiary/secondary/error environment-dot sequence).
  static const List<Color> folderIconPalette = [secondary, primary, tertiary];

  static Color folderIconColor(int index) =>
      folderIconPalette[index % folderIconPalette.length];
}
