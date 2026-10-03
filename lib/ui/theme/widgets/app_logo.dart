import 'package:flutter/material.dart';

import '../app_colors.dart';

/// The playground's brand mark: a lime rounded square with two dark dots
/// (the `.mark` in the header / favicon of `commodo-api-playground.html`),
/// hand-painted so no `flutter_svg` dependency is needed.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _AppLogoPainter()),
    );
  }
}

class _AppLogoPainter extends CustomPainter {
  const _AppLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Geometry from the favicon's 32x32 viewBox: rx 8, dots r 3.2 at (12,16)
    // and (20,16).
    final scale = size.width / 32;
    canvas.save();
    canvas.scale(scale);

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 32, 32), const Radius.circular(8)),
      Paint()..color = AppColors.primary,
    );
    final dot = Paint()..color = AppColors.onPrimary;
    canvas.drawCircle(const Offset(12, 16), 3.2, dot);
    canvas.drawCircle(const Offset(20, 16), 3.2, dot);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppLogoPainter oldDelegate) => false;
}
