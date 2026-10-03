import 'package:flutter/material.dart';

/// Design tokens from the `:root` block of `commodo-api-playground.html`
/// (see SPEC-ui-theme.md for the HTML-variable -> role mapping). Member
/// names follow the Material 3 role vocabulary so existing consumers keep
/// compiling; only the values changed from the old indigo/cyan palette.
/// Roles the HTML doesn't define are derived from the lime accent.
class AppColors {
  const AppColors._();

  static const Color surface = Color(0xFF10110E); // --bg
  static const Color surfaceDim = Color(0xFF10110E);
  static const Color surfaceBright = Color(0xFF373A28);
  static const Color surfaceContainerLowest = Color(0xFF0C0D0A); // pre/code bg
  static const Color surfaceContainerLow = Color(0xFF171910); // --bg-2
  static const Color surfaceContainer = Color(0xFF202318); // --bg-3
  static const Color surfaceContainerHigh = Color(0xFF282B1E); // --bg-4
  static const Color surfaceContainerHighest = Color(0xFF31351F);
  static const Color onSurface = Color(0xFFF4F5EE); // --text
  static const Color onSurfaceVariant = Color(0xFFA3A892); // --muted
  static const Color inverseSurface = Color(0xFFF4F5EE);
  static const Color inverseOnSurface = Color(0xFF202318);
  static const Color outline = Color(0xFF737864); // --faint
  static const Color outlineVariant = Color(0xFF2B2D26); // --line, flattened
  static const Color surfaceTint = Color(0xFFD6FF4A);

  static const Color primary = Color(0xFFD6FF4A); // --accent
  static const Color onPrimary = Color(0xFF141A08); // --ink
  static const Color primaryContainer = Color(0xFF4A6600);
  static const Color onPrimaryContainer = Color(0xFFE6FFA0);
  static const Color inversePrimary = Color(0xFF5A7A00);

  static const Color secondary = Color(0xFFA3D93A);
  static const Color onSecondary = Color(0xFF141A08);
  static const Color secondaryContainer = Color(0xFF3D5212);
  static const Color onSecondaryContainer = Color(0xFFE0F7A8);

  static const Color tertiary = Color(0xFFB6F25C); // --ok
  static const Color onTertiary = Color(0xFF141A08);
  static const Color tertiaryContainer = Color(0xFF3A5A14);
  static const Color onTertiaryContainer = Color(0xFFE8FFC4);

  static const Color error = Color(0xFFFF6B4A); // --danger
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFF5C1A0D);
  static const Color onErrorContainer = Color(0xFFFFDAD2);

  static const Color warning = Color(0xFFFFD27A); // --warn

  static const Color background = Color(0xFF10110E);
  static const Color onBackground = Color(0xFFF4F5EE);
  static const Color surfaceVariant = Color(0xFF31351F);

  // -- Semantic extension: layered on top of the M3 roles above, not part
  // of them. Sourced from DESIGN.md's prose "Method Badge System" /
  // "Status Code Badges" / "Variable Chips" component sections, which give
  // explicit hex values the frontmatter doesn't cover.

  static const Color methodGet = Color(0xFF9DFFB0);
  static const Color methodPost = Color(0xFF9EC1FF);
  static const Color methodPut = Color(0xFFFFD27A);
  static const Color methodPatch = Color(0xFFFFB86B);
  static const Color methodDelete = Color(0xFFFF8D8D);
  static const Color methodOther = outline;

  static const Color status2xx = Color(0xFFB6F25C);
  static const Color status3xx = Color(0xFF9EC1FF);
  static const Color status4xx = Color(0xFFFFD27A);
  static const Color status5xx = Color(0xFFFF6B4A);

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
