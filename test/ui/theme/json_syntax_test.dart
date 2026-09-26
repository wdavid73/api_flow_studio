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

  test('colors an object key with the secondary token color', () {
    final spans = tokenizeJsonLike('{"email":"a@b.com"}', baseStyle: base);

    expect(colorOf(spans, '"email"'), AppColors.secondary);
  });

  test('colors a string value with the tertiary token color', () {
    final spans = tokenizeJsonLike('{"email":"a@b.com"}', baseStyle: base);

    expect(colorOf(spans, '"a@b.com"'), AppColors.tertiary);
  });

  test('colors a number and a boolean with the primary token color', () {
    final spans = tokenizeJsonLike('{"age":42,"active":true}', baseStyle: base);

    expect(colorOf(spans, '42'), AppColors.primary);
    expect(colorOf(spans, 'true'), AppColors.primary);
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
}
