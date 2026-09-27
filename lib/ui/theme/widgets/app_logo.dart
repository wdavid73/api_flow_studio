import 'package:flutter/material.dart';

/// Hand-painted reproduction of `design/api_flow_studio_logo/code.html`'s
/// SVG mark -- no `flutter_svg` dependency, matching this project's
/// existing pattern for small vector graphics (see
/// `theme/widgets/json_syntax.dart`'s hand-rolled tokenizer).
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AppLogoPainter()),
    );
  }
}

class _AppLogoPainter extends CustomPainter {
  static const _background = Color(0xFF181824);
  static const _border = Color(0xFF31354C);
  static const _indigo = Color(0xFF6366F1);
  static const _cyan = Color(0xFF06B6D4);

  @override
  void paint(Canvas canvas, Size size) {
    // The source SVG is drawn on a 40x40 viewBox; scale uniformly to fit.
    final scale = size.width / 40;
    canvas.save();
    canvas.scale(scale);

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 40, 40), const Radius.circular(8)),
      Paint()..color = _background,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(0.5, 0.5, 39, 39), const Radius.circular(7.5)),
      Paint()
        ..color = _border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final barPaint = Paint()
      ..color = _indigo
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(10, 20), const Offset(15, 20), barPaint);
    canvas.drawLine(const Offset(25, 20), const Offset(30, 20), barPaint);

    canvas.drawCircle(const Offset(20, 20), 4.5, Paint()..color = _indigo.withValues(alpha: 0.2));
    canvas.drawCircle(
      const Offset(20, 20),
      4.5,
      Paint()
        ..color = _indigo
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final chevronPaint = Paint()
      ..color = _cyan
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(12, 14)
        ..lineTo(8, 20)
        ..lineTo(12, 26),
      chevronPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(28, 14)
        ..lineTo(32, 20)
        ..lineTo(28, 26),
      chevronPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppLogoPainter oldDelegate) => false;
}
