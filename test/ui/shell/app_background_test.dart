import 'package:api_flow_studio/ui/shell/app_background.dart';
import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('paints a lime radial glow over the surface color', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: AppBackground(child: SizedBox()),
    ));

    final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
    final decoration = box.decoration as BoxDecoration;
    final gradient = decoration.gradient! as RadialGradient;

    expect(decoration.color, AppColors.surface);
    expect(gradient.colors.first, AppColors.backgroundGlow);
    expect(gradient.colors.last.a, 0);
  });
}
