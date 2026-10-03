/// Spacing scale copied from `design/api_flow_studio/DESIGN.md`'s YAML
/// frontmatter `spacing` block (values converted from rem at 16px/rem).
class AppSpacing {
  const AppSpacing._();

  static const double gutter = 1;
  static const double gutterSplit = 4;
  static const double margin = 12;
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;
}

/// Corner radius scale copied from the same file's `rounded` block.
class AppRadius {
  const AppRadius._();

  static const double sm = 2;
  static const double md = 4;
  static const double lg = 6;
  static const double xl = 8;
  static const double xxl = 12;
  static const double full = 9999;

  // Radii from the playground HTML (fields/buttons, code blocks, dialogs).
  static const double field = 10;
  static const double block = 12;
  static const double dialog = 16;
}
