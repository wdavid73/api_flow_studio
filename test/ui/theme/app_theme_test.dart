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

  Color? decoratedColor(WidgetTester tester, Finder finder) {
    final decoration = tester.widget<Container>(finder).decoration as BoxDecoration?;
    return decoration?.color;
  }

  Widget wrapWithTheme(Widget child) => MaterialApp(theme: AppTheme.dark(), home: Material(child: child));

  group('MethodBadge', () {
    testWidgets('colors GET blue and shows uppercase text', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const MethodBadge(method: 'get')));

      expect(find.text('GET'), findsOneWidget);
      expect(decoratedColor(tester, find.byType(Container)), AppColors.methodGet.withValues(alpha: 0.12));
    });

    testWidgets('colors DELETE red', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const MethodBadge(method: 'DELETE')));

      expect(decoratedColor(tester, find.byType(Container)), AppColors.methodDelete.withValues(alpha: 0.12));
    });

    testWidgets('falls back to methodOther for an unknown verb', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const MethodBadge(method: 'TRACE')));

      expect(decoratedColor(tester, find.byType(Container)), AppColors.methodOther.withValues(alpha: 0.12));
    });
  });

  group('StatusBadge', () {
    testWidgets('colors a 2xx status with the success color', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const StatusBadge(statusCode: 200)));

      expect(find.text('200'), findsOneWidget);
      expect(decoratedColor(tester, find.byType(Container)), AppColors.status2xx.withValues(alpha: 0.15));
    });

    testWidgets('colors a 4xx status with the client-error color', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const StatusBadge(statusCode: 404)));

      expect(decoratedColor(tester, find.byType(Container)), AppColors.status4xx.withValues(alpha: 0.15));
    });

    testWidgets('colors a 5xx status with the server-error color', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const StatusBadge(statusCode: 500)));

      expect(decoratedColor(tester, find.byType(Container)), AppColors.status5xx.withValues(alpha: 0.15));
    });
  });

  group('VariableChip', () {
    testWidgets('renders the resolved cyan style with the {{name}} text', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const VariableChip(name: 'base_url', resolved: true)));

      expect(find.text('{{base_url}}'), findsOneWidget);
      expect(decoratedColor(tester, find.byType(Container)), AppColors.variableResolvedBg);
    });

    testWidgets('renders the unresolved amber style', (tester) async {
      await tester.pumpWidget(wrapWithTheme(const VariableChip(name: 'missing', resolved: false)));

      expect(decoratedColor(tester, find.byType(Container)), AppColors.variableUnresolvedBg);
    });
  });
}
