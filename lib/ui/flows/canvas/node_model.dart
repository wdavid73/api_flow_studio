import '../../../engine/flows/input_origin.dart';
import '../../../engine/flows/response_fields.dart';
import '../../../engine/flows/step_inputs.dart';
import '../../../engine/models/models.dart';
import '../../../engine/session/session_apply.dart';
import '../step_response.dart';
import 'canvas_metrics.dart';

enum InputRowKind { variable, generated, session, none }

/// One row of a node's INPUTS section.
class InputRow {
  const InputRow({required this.kind, required this.label, this.origin});

  final InputRowKind kind;

  /// The variable name, `$token` for a generated one, `Authorization` for the
  /// session row; empty for the "no variables" row.
  final String label;

  /// Where a [InputRowKind.variable] input comes from; null for the others.
  final InputOrigin? origin;
}

/// Everything a node shows, worked out once per build so the node and the
/// wires agree on rows and positions.
class NodeModel {
  const NodeModel({
    required this.index,
    required this.endpoint,
    required this.inputs,
    required this.response,
    required this.fields,
    required this.extract,
  });

  final int index;
  final Endpoint? endpoint;
  final List<InputRow> inputs;
  final StepResponse? response;

  /// The fields of [response] when it is JSON; null otherwise.
  final ResponseFields? fields;
  final Map<String, String> extract;

  bool get hasResponse => response != null;

  List<ResponseField> get visibleFields =>
      fields == null ? const [] : fields!.fields.take(maxVisibleFields).toList();

  int get hiddenFieldCount => fields == null ? 0 : fields!.fields.length - visibleFields.length + fields!.omitted;

  /// Rows of the response section: the visible fields (or one message row
  /// when there are none) plus a "+N more" row when fields are hidden.
  int get responseRowCount {
    if (!hasResponse) return 0;
    final fieldRows = visibleFields.isEmpty ? 1 : visibleFields.length;
    return fieldRows + (hiddenFieldCount > 0 ? 1 : 0);
  }

  double get height => nodeHeight(inputs.length, responseRowCount, hasResponse: hasResponse);
}

/// The [NodeModel] of step [index]. Input rows come in a fixed order --
/// variables, then generated tokens, then the session row -- and a step
/// without any gets one "no variables" row, so every node has the same shape.
NodeModel buildNodeModel({
  required Flow flow,
  required int index,
  required Endpoint? endpoint,
  required StepResponse? response,
  required Map<String, String> environmentVariables,
  required bool sessionAttachAuth,
}) {
  final rows = <InputRow>[];
  if (endpoint != null) {
    final inputs = stepInputs(endpoint);
    for (final name in inputs.variables) {
      rows.add(InputRow(
        kind: InputRowKind.variable,
        label: name,
        origin: resolveInputOrigin(flow, index, name, environmentVariables),
      ));
    }
    for (final name in inputs.generated) {
      rows.add(InputRow(kind: InputRowKind.generated, label: '\$$name'));
    }
    if (sessionAttachAuth && acceptsSessionToken(endpoint)) {
      rows.add(const InputRow(kind: InputRowKind.session, label: 'Authorization'));
    }
  }
  if (rows.isEmpty) rows.add(const InputRow(kind: InputRowKind.none, label: ''));

  return NodeModel(
    index: index,
    endpoint: endpoint,
    inputs: rows,
    response: response,
    fields: response != null && response.isJson ? responseFields(response.body) : null,
    extract: flow.steps[index].extract,
  );
}
