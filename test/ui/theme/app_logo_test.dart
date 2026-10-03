import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:api_flow_studio/ui/theme/widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Finder markPaint() => find.descendant(of: find.byType(AppLogoMark), matching: find.byType(CustomPaint));

  for (final size in [28.0, 56.0]) {
    testWidgets('draws an accent rounded square with two ink dots at size $size', (tester) async {
      await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: Align(child: AppLogoMark(size: size))));

      expect(tester.getSize(find.byType(AppLogoMark)), Size(size, size));
      expect(
        tester.renderObject(markPaint()),
        paints
          ..rrect(color: AppColors.primary)
          ..circle(color: AppColors.onPrimary)
          ..circle(color: AppColors.onPrimary),
      );
    });
  }
}
