import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/widgets/json_syntax.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = TextStyle(color: AppColors.onSurface);

  Color? colorOf(List<InlineSpan> spans, String text) {
    for (final span in spans) {
      if (span is TextSpan && span.text == text) return span.style?.color;
    }
    return null;
  }

  test('colors an object key with the accent token color', () {
    final spans = tokenizeJsonLike('{"email":"a@b.com"}', baseStyle: base);

    expect(colorOf(spans, '"email"'), const Color(0xFFA78BFA));
  });

  test('colors a string value with the peach string token color', () {
    final spans = tokenizeJsonLike('{"email":"a@b.com"}', baseStyle: base);

    expect(colorOf(spans, '"a@b.com"'), const Color(0xFFFFD7A8));
  });

  test('colors numbers blue and booleans/null red', () {
    final spans = tokenizeJsonLike('{"age":42,"active":true,"x":null}', baseStyle: base);

    expect(colorOf(spans, '42'), const Color(0xFF9EC1FF));
    expect(colorOf(spans, 'true'), const Color(0xFFFF8D8D));
    expect(colorOf(spans, 'null'), const Color(0xFFFF8D8D));
  });

  test('variable tokens use the accent and warning tints', () {
    expect(AppColors.variableResolvedText, AppColors.primary);
    expect(AppColors.variableUnresolvedText, AppColors.warning);
    expect(AppColors.variableResolvedBg, const Color(0x1FA78BFA));
    expect(AppColors.variableUnresolvedBg, const Color(0x26FFD27A));
  });

  test('surface tokens for response, banner and info areas', () {
    expect(AppColors.responseBackground, const Color(0xFF12111A));
    expect(AppColors.bannerBackground, const Color(0xFF2A2416));
    expect(AppColors.infoBackground, const Color(0xFF171C28));
  });

  test('colors a {{variable}} token with the variable-resolved color', () {
    final spans = tokenizeJsonLike('{"email":"{{user_email}}"}', baseStyle: base);

    expect(colorOf(spans, '{{user_email}}'), AppColors.variableResolvedText);
  });

  test('colors punctuation with on-surface-variant', () {
    final spans = tokenizeJsonLike('{}', baseStyle: base);

    expect(colorOf(spans, '{'), AppColors.onSurfaceVariant);
    expect(colorOf(spans, '}'), AppColors.onSurfaceVariant);
  });

  test('plain text with no JSON tokens returns it verbatim in the base style', () {
    final spans = tokenizeJsonLike('not json', baseStyle: base);

    expect(spans, hasLength(1));
    expect((spans.single as TextSpan).text, 'not json');
    expect(spans.single.style?.color, AppColors.onSurface);
  });

  group('tokenizeVariablesOnly', () {
    test('colors a resolved variable cyan', () {
      final spans = tokenizeVariablesOnly(
        '{{base_url}}/users',
        baseStyle: base,
        resolvedVariables: {'base_url': 'https://api.dev'},
      );

      expect(colorOf(spans, '{{base_url}}'), AppColors.variableResolvedText);
    });

    test('colors an unresolved variable amber', () {
      final spans = tokenizeVariablesOnly(
        '{{nope}}/users',
        baseStyle: base,
        resolvedVariables: {'base_url': 'https://api.dev'},
      );

      expect(colorOf(spans, '{{nope}}'), AppColors.variableUnresolvedText);
    });

    test('treats every variable as resolved when no map is given', () {
      final spans = tokenizeVariablesOnly('{{anything}}', baseStyle: base);

      expect(colorOf(spans, '{{anything}}'), AppColors.variableResolvedText);
    });

    test('leaves plain text (no variables) untouched', () {
      final spans = tokenizeVariablesOnly('https://api.dev/users', baseStyle: base);

      expect(spans, hasLength(1));
      expect((spans.single as TextSpan).text, 'https://api.dev/users');
    });
  });
}
