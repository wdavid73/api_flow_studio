import 'dart:math' as math;
import 'dart:ui';

import '../../../engine/flows/input_origin.dart';
import 'canvas_metrics.dart';
import 'node_model.dart';

/// One value travelling between two steps, as drawn on the canvas: from the
/// pin of a response field of [fromStep] to the pin of the [variable] input of
/// [toStep]. Positions are in canvas coordinates (zoom 1).
class Wire {
  const Wire({
    required this.fromStep,
    required this.toStep,
    required this.variable,
    required this.from,
    required this.to,
    this.suggestion = false,
  });

  final int fromStep;
  final int toStep;
  final String variable;
  final Offset from;
  final Offset to;

  /// Not a connection yet: a proposed one, drawn dashed.
  final bool suggestion;

  /// How far the curve's control points sit from its ends.
  double get bend => math.max(40, (to.dx - from.dx).abs() / 2);

  /// The middle of the curve (the Bézier at t = 0.5).
  Offset get midpoint {
    final c1 = from + Offset(bend, 0);
    final c2 = to - Offset(bend, 0);
    return (from + c1 * 3 + c2 * 3 + to) / 8;
  }

  @override
  bool operator ==(Object other) =>
      other is Wire &&
      other.fromStep == fromStep &&
      other.toStep == toStep &&
      other.variable == variable &&
      other.from == from &&
      other.to == to &&
      other.suggestion == suggestion;

  @override
  int get hashCode => Object.hash(fromStep, toStep, variable, from, to, suggestion);
}

/// Where the pin of input row [row] of [node] is.
Offset inputPinOffset(NodeModel node, int row) =>
    Offset(nodeLeft(node.index), canvasPadding + inputRowCenterY(row));

/// Where the pin of visible response field [fieldRow] of [node] is.
Offset fieldPinOffset(NodeModel node, int fieldRow) =>
    Offset(nodeLeft(node.index) + nodeWidth, canvasPadding + fieldRowCenterY(node.inputs.length, fieldRow));

/// The right edge of [node]'s header: where a wire starts when the value it
/// carries is not one of the fields the node shows (`response.status`, a
/// header, a field past the first ones, or no response yet).
Offset headerAnchor(NodeModel node) => Offset(nodeLeft(node.index) + nodeWidth, canvasPadding + headerHeight / 2);

/// Every connection of the flow: one wire per input that takes its value from
/// an earlier step's extract.
List<Wire> computeWires(List<NodeModel> nodes) {
  final wires = <Wire>[];
  for (final node in nodes) {
    for (var row = 0; row < node.inputs.length; row++) {
      final input = node.inputs[row];
      final origin = input.origin;
      if (input.kind != InputRowKind.variable || origin is! FromStep) continue;
      final producer = nodes[origin.stepIndex];
      final field = producer.visibleFields.indexWhere((f) => f.path == origin.path);
      wires.add(Wire(
        fromStep: origin.stepIndex,
        toStep: node.index,
        variable: input.label,
        from: field >= 0 ? fieldPinOffset(producer, field) : headerAnchor(producer),
        to: inputPinOffset(node, row),
      ));
    }
  }
  return wires;
}
