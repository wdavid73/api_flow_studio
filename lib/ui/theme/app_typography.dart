import 'package:flutter/material.dart';

/// Text styles copied from `design/api_flow_studio/DESIGN.md`'s YAML
/// frontmatter `typography` block. Kept as named constants matching that
/// file's own vocabulary (headline-lg, body-md, code-sm, ...) rather than
/// shoehorned into Flutter's fixed TextTheme slot names, which don't map
/// cleanly onto this design system's scale.
class AppTypography {
  const AppTypography._();

  static const String uiFontFamily = 'Geist';
  static const String codeFontFamily = 'JetBrains Mono';

  static const TextStyle headlineLg = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 28 / 20,
  );

  static const TextStyle headlineMd = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 24 / 16,
  );

  static const TextStyle headlineSm = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 20 / 14,
  );

  static const TextStyle bodyLg = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 16 / 12,
  );

  static const TextStyle codeLg = TextStyle(
    fontFamily: codeFontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 20 / 13,
  );

  static const TextStyle codeMd = TextStyle(
    fontFamily: codeFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 18 / 12,
  );

  static const TextStyle codeSm = TextStyle(
    fontFamily: codeFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 16 / 11,
  );

  static const TextStyle labelMd = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    letterSpacing: 0.12, // 0.01em
  );

  static const TextStyle labelSm = TextStyle(
    fontFamily: uiFontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 14 / 11,
    letterSpacing: 0.22, // 0.02em
  );

  static const TextStyle badgeMono = TextStyle(
    fontFamily: codeFontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    height: 12 / 10,
    letterSpacing: 0.4, // 0.04em
  );
}
