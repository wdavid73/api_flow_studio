import 'package:flutter/material.dart';

/// Design tokens, laid out like the `:root` block of
/// `commodo-api-playground.html` (see SPEC-ui-theme.md). The playground's lime
/// accent was swapped for a soft violet and its olive-tinted blacks for
/// violet-tinted ones; success keeps a green (mint). Member names follow the
/// Material 3 role vocabulary so consumers are unaffected. Roles the HTML
/// doesn't define are derived from the violet accent.
class AppColors {
  const AppColors._();

  static const Color surface = Color(0xFF0F0E14); // --bg
  static const Color surfaceDim = Color(0xFF0F0E14);
  static const Color surfaceBright = Color(0xFF363448);
  static const Color surfaceContainerLowest = Color(0xFF0A0A0F); // pre/code bg
  static const Color surfaceContainerLow = Color(0xFF15141C); // --bg-2
  static const Color surfaceContainer = Color(0xFF1C1B26); // --bg-3
  static const Color surfaceContainerHigh = Color(0xFF252433); // --bg-4
  static const Color surfaceContainerHighest = Color(0xFF2F2E40);
  static const Color onSurface = Color(0xFFF1F0F7); // --text
  static const Color onSurfaceVariant = Color(0xFFA09EB5); // --muted
  static const Color inverseSurface = Color(0xFFF1F0F7);
  static const Color inverseOnSurface = Color(0xFF1C1B26);
  static const Color outline = Color(0xFF6F6D85); // --faint
  static const Color outlineVariant = Color(0xFF2A2937); // --line, flattened
  static const Color surfaceTint = Color(0xFFA78BFA);

  static const Color primary = Color(0xFFA78BFA); // --accent
  static const Color onPrimary = Color(0xFF17102B); // ink: dark violet, readable on the accent
  static const Color primaryContainer = Color(0xFF4B3A8C);
  static const Color onPrimaryContainer = Color(0xFFE9E1FF);
  static const Color inversePrimary = Color(0xFF6B4FD6);

  static const Color secondary = Color(0xFFD8A7F5);
  static const Color onSecondary = Color(0xFF17102B);
  static const Color secondaryContainer = Color(0xFF4A2F63);
  static const Color onSecondaryContainer = Color(0xFFF3E3FF);

  static const Color tertiary = Color(0xFF86E7B0); // --ok
  static const Color onTertiary = Color(0xFF17102B);
  static const Color tertiaryContainer = Color(0xFF1F5A3E);
  static const Color onTertiaryContainer = Color(0xFFD7FBE6);

  static const Color error = Color(0xFFFF6B4A); // --danger
  static const Color onError = Color(0xFF17102B); // ink: white on --danger is only 2.8:1
  static const Color errorContainer = Color(0xFF5C1A0D);
  static const Color onErrorContainer = Color(0xFFFFDAD2);

  static const Color warning = Color(0xFFFFD27A); // --warn

  /// Faint violet glow behind the shell top-left corner (8 percent of the accent).
  static const Color backgroundGlow = Color(0x14A78BFA);

  static const Color background = Color(0xFF0F0E14);
  static const Color onBackground = Color(0xFFF1F0F7);
  static const Color surfaceVariant = Color(0xFF2F2E40);

  // -- Semantic extension: layered on top of the M3 roles above, not part
  // of them. Sourced from the playground's .verb / .status / .tok-* rules.

  static const Color methodGet = Color(0xFF9DFFB0);
  static const Color methodPost = Color(0xFF9EC1FF);
  static const Color methodPut = Color(0xFFFFD27A);
  static const Color methodPatch = Color(0xFFFFB86B);
  static const Color methodDelete = Color(0xFFFF8D8D);
  static const Color methodOther = outline;

  static const Color status2xx = Color(0xFF86E7B0);
  static const Color status3xx = Color(0xFF9EC1FF);
  static const Color status4xx = Color(0xFFFFD27A);
  static const Color status5xx = Color(0xFFFF6B4A);

  static const Color variableResolvedText = primary;
  static const Color variableResolvedBg = Color(0x1FA78BFA); // ~12% alpha
  static const Color variableResolvedBorder = Color(0x47A78BFA); // ~28% alpha
  static const Color variableUnresolvedText = warning;
  static const Color variableUnresolvedBg = Color(0x26FFD27A); // ~15% alpha

  // JSON syntax tokens (.tok-* in the playground).
  static const Color jsonKey = primary;
  static const Color jsonString = Color(0xFFFFD7A8);
  static const Color jsonNumber = Color(0xFF9EC1FF);
  static const Color jsonKeyword = Color(0xFFFF8D8D);

  // Area backgrounds the HTML hardcodes outside :root.
  static const Color responseBackground = Color(0xFF12111A);
  static const Color bannerBackground = Color(0xFF2A2416);
  static const Color infoBackground = Color(0xFF171C28);

  /// Dots for non-production environments. Red is reserved for production
  /// (see `environmentDotColorFor`), so it is not in this cycle.
  static const List<Color> environmentDotPalette = [primary, tertiary, secondary];

  static Color environmentDotColor(int index) =>
      environmentDotPalette[index % environmentDotPalette.length];

  // Sidebar top-level folder icons cycle through a different palette than
  // environments (design/*/code.html shows folders in secondary/primary/
  // tertiary, not the tertiary/secondary/error environment-dot sequence).
  static const List<Color> folderIconPalette = [secondary, primary, tertiary];

  static Color folderIconColor(int index) =>
      folderIconPalette[index % folderIconPalette.length];
}
