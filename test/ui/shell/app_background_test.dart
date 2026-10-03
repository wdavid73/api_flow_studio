import 'package:api_flow_studio/ui/shell/app_background.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpBackground(WidgetTester tester) => tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: AppBackground(child: SizedBox()),
      ));

  testWidgets('paints an opaque surface layer under the glow', (tester) async {
    await pumpBackground(tester);

    // A gradient decoration ignores its own color, so the dark base has to
    // be a separate layer or the transparent end of the glow shows white.
    final base = tester.widget<ColoredBox>(
      find.descendant(of: find.byType(AppBackground), matching: find.byType(ColoredBox)).first,
    );

    expect(base.color, AppColors.surface);
    expect(base.color.a, 1);
  });

  testWidgets('draws a lime radial glow fading to transparent', (tester) async {
    await pumpBackground(tester);

    final box = tester.widget<DecoratedBox>(
      find.descendant(of: find.byType(AppBackground), matching: find.byType(DecoratedBox)).first,
    );
    final gradient = (box.decoration as BoxDecoration).gradient! as RadialGradient;

    expect(gradient.colors.first, AppColors.backgroundGlow);
    expect(gradient.colors.last.a, 0);
  });
}
