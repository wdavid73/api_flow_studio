import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/app_spacing.dart';
import 'package:api_flow_studio/ui/theme/app_theme.dart';
import 'package:api_flow_studio/ui/theme/app_typography.dart';
import 'package:api_flow_studio/ui/theme/widgets/method_badge.dart';
import 'package:api_flow_studio/ui/theme/widgets/status_badge.dart';
import 'package:api_flow_studio/ui/theme/widgets/variable_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors Commodo tokens', () {
    test('surfaces follow the playground :root backgrounds', () {
      expect(AppColors.surface, const Color(0xFF10110E));
      expect(AppColors.surfaceContainerLowest, const Color(0xFF0C0D0A));
      expect(AppColors.surfaceContainerLow, const Color(0xFF171910));
      expect(AppColors.surfaceContainer, const Color(0xFF202318));
      expect(AppColors.surfaceContainerHigh, const Color(0xFF282B1E));
      expect(AppColors.surfaceContainerHighest, const Color(0xFF31351F));
    });

    test('text and outline tokens', () {
      expect(AppColors.onSurface, const Color(0xFFF4F5EE));
      expect(AppColors.onSurfaceVariant, const Color(0xFFA3A892));
      expect(AppColors.outline, const Color(0xFF737864));
      expect(AppColors.outlineVariant, const Color(0xFF2B2D26));
    });

    test('accent, status and derived roles', () {
      expect(AppColors.primary, const Color(0xFFD6FF4A));
      expect(AppColors.onPrimary, const Color(0xFF141A08));
      expect(AppColors.error, const Color(0xFFFF6B4A));
      expect(AppColors.tertiary, const Color(0xFFB6F25C));
      expect(AppColors.warning, const Color(0xFFFFD27A));
      expect(AppColors.secondary, const Color(0xFFA3D93A));
      expect(AppColors.secondaryContainer, const Color(0xFF3D5212));
      expect(AppColors.primaryContainer, const Color(0xFF4A6600));
      expect(AppColors.inversePrimary, const Color(0xFF5A7A00));
    });
  });

  group('AppTheme.dark colorScheme', () {
    test('matches the Commodo tokens', () {
      final scheme = AppTheme.dark().colorScheme;

      expect(scheme.surface, AppColors.surface);
      expect(scheme.primary, AppColors.primary);
      expect(scheme.secondary, AppColors.secondary);
      expect(scheme.tertiary, AppColors.tertiary);
      expect(scheme.error, AppColors.error);
      expect(scheme.brightness, Brightness.dark);
    });

    test('scaffoldBackgroundColor is the surface token', () {
      expect(AppTheme.dark().scaffoldBackgroundColor, AppColors.surface);
    });
  });

  group('AppSpacing / AppRadius', () {
    test('spacing matches the DESIGN.md scale in px', () {
      expect(AppSpacing.xs, 4);
      expect(AppSpacing.sm, 6);
      expect(AppSpacing.md, 10);
      expect(AppSpacing.lg, 14);
      expect(AppSpacing.xl, 20);
    });

    test('radius matches the DESIGN.md scale in px', () {
      expect(AppRadius.sm, 2);
      expect(AppRadius.md, 4);
      expect(AppRadius.lg, 6);
      expect(AppRadius.xl, 8);
      expect(AppRadius.xxl, 12);
      expect(AppRadius.full, 9999);
    });
  });

  group('AppTypography', () {
    test('body/headline styles use the Geist family', () {
      expect(AppTypography.headlineLg.fontFamily, 'Geist');
      expect(AppTypography.bodyMd.fontFamily, 'Geist');
    });

    test('code/badge styles use the JetBrains Mono family', () {
      expect(AppTypography.codeMd.fontFamily, 'JetBrains Mono');
      expect(AppTypography.badgeMono.fontFamily, 'JetBrains Mono');
    });
  });

  group('Playground radii and type', () {
    test('adds the HTML radii without changing the existing scale', () {
      expect(AppRadius.field, 10);
      expect(AppRadius.dialog, 16);
      expect(AppRadius.block, 12);
      expect(AppRadius.xl, 8);
    });

    test('kicker and title styles follow the HTML', () {
      expect(AppTypography.kicker.fontSize, 11);
      expect(AppTypography.kicker.letterSpacing, closeTo(0.88, 0.001));
      expect(AppTypography.title.fontSize, 18);
      expect(AppTypography.title.letterSpacing, closeTo(-0.54, 0.001));
      expect(AppTypography.title.fontFamily, 'Geist');
    });
  });

  group('AppTheme.dark component themes', () {
    final theme = AppTheme.dark();

    test('inputs use 10px radius, outlineVariant border and primary focus', () {
      final decoration = theme.inputDecorationTheme;
      final enabled = decoration.enabledBorder! as OutlineInputBorder;
      final focused = decoration.focusedBorder! as OutlineInputBorder;

      expect(enabled.borderRadius, BorderRadius.circular(10));
      expect(enabled.borderSide.color, AppColors.outlineVariant);
      expect(focused.borderSide.color, AppColors.primary);
      expect(decoration.filled, isTrue);
      expect(decoration.fillColor, AppColors.surface);
    });

    test('filled buttons are lime on ink', () {
      final style = theme.filledButtonTheme.style!;

      expect(style.backgroundColor!.resolve({}), AppColors.primary);
      expect(style.foregroundColor!.resolve({}), AppColors.onPrimary);
    });

    test('a disabled filled button is muted, not lime', () {
      final style = theme.filledButtonTheme.style!;
      final disabled = <WidgetState>{WidgetState.disabled};

      expect(style.backgroundColor!.resolve(disabled), AppColors.surfaceContainerHigh);
      expect(style.foregroundColor!.resolve(disabled), AppColors.outline);
      expect(style.backgroundColor!.resolve(disabled), isNot(AppColors.primary));
    });

    test('a disabled outlined button dims its label', () {
      final style = theme.outlinedButtonTheme.style!;

      expect(style.foregroundColor!.resolve(<WidgetState>{WidgetState.disabled}), AppColors.outline);
      expect(style.foregroundColor!.resolve({}), AppColors.onSurface);
    });

    test('dialogs use 16px radius on surfaceContainerLow', () {
      final dialog = theme.dialogTheme;

      expect(dialog.backgroundColor, AppColors.surfaceContainerLow);
      expect((dialog.shape! as RoundedRectangleBorder).borderRadius, BorderRadius.circular(16));
    });

    test('dividers use the outlineVariant line color', () {
      expect(theme.dividerTheme.color, AppColors.outlineVariant);
    });

    test('keeps Geist as the default font family', () {
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Geist');
    });
  });

  Color? decoratedColor(WidgetTester tester, Finder finder) {
    final decoration = tester.widget<Container>(finder).decoration as BoxDecoration?;
    return decoration?.color;
  }

  Widget wrapWithTheme(Widget child) => MaterialApp(theme: AppTheme.dark(), home: Material(child: child));

  Color? textColor(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style?.color;

  group('MethodBadge', () {
    testWidgets('shows uppercase text in the GET color with no fill', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const MethodBadge(method: 'get')));

      expect(find.text('GET'), findsOneWidget);
      expect(textColor(tester, 'GET'), const Color(0xFF9DFFB0));
      expect(find.byType(DecoratedBox), findsNothing);
    });

    testWidgets('colors every verb per the playground palette', (tester) async {
      expect(MethodBadge.colorForMethod('POST'), const Color(0xFF9EC1FF));
      expect(MethodBadge.colorForMethod('PUT'), const Color(0xFFFFD27A));
      expect(MethodBadge.colorForMethod('PATCH'), const Color(0xFFFFB86B));
      expect(MethodBadge.colorForMethod('DELETE'), const Color(0xFFFF8D8D));
    });

    testWidgets('falls back to methodOther for an unknown verb', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const MethodBadge(method: 'TRACE')));

      expect(textColor(tester, 'TRACE'), AppColors.methodOther);
      expect(AppColors.methodOther, AppColors.outline);
    });
  });

  group('StatusBadge', () {
    testWidgets('colors a 2xx status with the ok color', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const StatusBadge(statusCode: 200)));

      expect(find.text('200'), findsOneWidget);
      expect(textColor(tester, '200'), const Color(0xFFB6F25C));
      expect(decoratedColor(tester, find.byType(Container)), const Color(0xFFB6F25C).withValues(alpha: 0.15));
    });

    testWidgets('colors a 3xx status blue', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const StatusBadge(statusCode: 302)));

      expect(textColor(tester, '302'), const Color(0xFF9EC1FF));
    });

    testWidgets('colors a 4xx status with the warn color', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const StatusBadge(statusCode: 404)));

      expect(textColor(tester, '404'), const Color(0xFFFFD27A));
    });

    testWidgets('colors a 5xx and a status 0 with the danger color', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const StatusBadge(statusCode: 500)));
      expect(textColor(tester, '500'), const Color(0xFFFF6B4A));

      await tester.pumpWidget(wrapWithTheme(const StatusBadge(statusCode: 0)));
      expect(textColor(tester, '0'), const Color(0xFFFF6B4A));
    });
  });

  group('VariableChip', () {
    testWidgets('renders the resolved accent style with the {{name}} text', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const VariableChip(name: 'base_url', resolved: true)));

      expect(find.text('{{base_url}}'), findsOneWidget);
      expect(decoratedColor(tester, find.byType(Container)), AppColors.variableResolvedBg);
    });

    testWidgets('renders the unresolved warning style', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const VariableChip(name: 'missing', resolved: false)));

      expect(decoratedColor(tester, find.byType(Container)), AppColors.variableUnresolvedBg);
    });
  });
}
