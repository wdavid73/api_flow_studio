import 'package:api_flow_studio/ui/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x contrast ratio between two opaque colors.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  void expectReadable(String name, Color foreground, Color background) {
    test('$name has at least 4.5:1 contrast', () {
      expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
    });
  }

  expectReadable('onPrimary on primary', AppColors.onPrimary, AppColors.primary);
  expectReadable('onSurface on surface', AppColors.onSurface, AppColors.surface);
  expectReadable('onSurfaceVariant on surface', AppColors.onSurfaceVariant, AppColors.surface);
  expectReadable('onSurface on surfaceContainerLow', AppColors.onSurface, AppColors.surfaceContainerLow);
  expectReadable('onError on error', AppColors.onError, AppColors.error);
  expectReadable('GET label on surface', AppColors.methodGet, AppColors.surface);
  expectReadable('DELETE label on surface', AppColors.methodDelete, AppColors.surface);
  expectReadable('warning on surface', AppColors.warning, AppColors.surface);
}
