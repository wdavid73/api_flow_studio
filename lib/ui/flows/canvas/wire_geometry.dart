import 'dart:math' as math;
import 'dart:ui';

import '../../../engine/flows/input_origin.dart';
import '../../../engine/flows/response_fields.dart';
import '../../../engine/flows/variable_naming.dart';
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
    required this.path,
    required this.from,
    required this.to,
    this.suggestion = false,
  });

  final int fromStep;
  final int toStep;
  final String variable;

  /// The response path of [fromStep] the value comes from.
  final String path;
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
      other.path == path &&
      other.from == from &&
      other.to == to &&
      other.suggestion == suggestion;

  @override
  int get hashCode => Object.hash(fromStep, toStep, variable, path, from, to, suggestion);
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

/// Every connection of the flow -- one wire per input that takes its value
/// from an earlier step's extract -- plus one dashed suggestion per input
/// without a source when an earlier step's response has a field of the same
/// name (see [suggestConnection]).
List<Wire> computeWires(List<NodeModel> nodes) {
  final fieldsByStep = <int, List<ResponseField>>{
    for (final node in nodes) node.index: node.fields?.fields ?? const <ResponseField>[],
  };
  Offset start(NodeModel producer, String path) {
    final field = producer.visibleFields.indexWhere((f) => f.path == path);
    return field >= 0 ? fieldPinOffset(producer, field) : headerAnchor(producer);
  }

  final wires = <Wire>[];
  for (final node in nodes) {
    for (var row = 0; row < node.inputs.length; row++) {
      final input = node.inputs[row];
      final origin = input.origin;
      if (input.kind != InputRowKind.variable) continue;
      if (origin is FromStep) {
        wires.add(Wire(
          fromStep: origin.stepIndex,
          toStep: node.index,
          variable: input.label,
          path: origin.path,
          from: start(nodes[origin.stepIndex], origin.path),
          to: inputPinOffset(node, row),
        ));
      } else if (origin is Missing) {
        final match = suggestConnection(name: input.label, stepIndex: node.index, fieldsByStep: fieldsByStep);
        if (match == null) continue;
        wires.add(Wire(
          fromStep: match.stepIndex,
          toStep: node.index,
          variable: input.label,
          path: match.path,
          from: start(nodes[match.stepIndex], match.path),
          to: inputPinOffset(node, row),
          suggestion: true,
        ));
      }
    }
  }
  return wires;
}
