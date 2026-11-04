import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../../theme/app_colors.dart';
import 'wire_geometry.dart';

/// Draws the [wires] of the canvas as horizontal Bézier curves -- solid for a
/// connection, dashed for a suggestion -- plus, while a field is being
/// dragged, a dashed "ghost" from its pin to the pointer.
class WirePainter extends CustomPainter {
  const WirePainter({required this.wires, this.ghostFrom, this.ghostTo});

  final List<Wire> wires;
  final Offset? ghostFrom;
  final Offset? ghostTo;

  @override
  void paint(Canvas canvas, Size size) {
    for (final wire in wires) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = wire.suggestion ? AppColors.warning : AppColors.primary;
      final path = _curve(wire.from, wire.to, wire.bend);
      canvas.drawPath(wire.suggestion ? _dashed(path) : path, paint);
    }
    final from = ghostFrom;
    final to = ghostTo;
    if (from != null && to != null) {
      final ghost = Wire(fromStep: 0, toStep: 0, variable: '', path: '', from: from, to: to);
      canvas.drawPath(
        _dashed(_curve(from, to, ghost.bend)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = AppColors.primary.withValues(alpha: 0.7),
      );
    }
  }

  Path _curve(Offset from, Offset to, double bend) => Path()
    ..moveTo(from.dx, from.dy)
    ..cubicTo(from.dx + bend, from.dy, to.dx - bend, to.dy, to.dx, to.dy);

  Path _dashed(Path source, {double dash = 5, double gap = 4}) {
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += dash + gap) {
        dashed.addPath(metric.extractPath(distance, distance + dash), Offset.zero);
      }
    }
    return dashed;
  }

  @override
  bool shouldRepaint(WirePainter oldDelegate) =>
      !listEquals(wires, oldDelegate.wires) || ghostFrom != oldDelegate.ghostFrom || ghostTo != oldDelegate.ghostTo;
}
