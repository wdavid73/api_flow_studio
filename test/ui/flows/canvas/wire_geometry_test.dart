import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/ui/flows/canvas/canvas_metrics.dart';
import 'package:api_flow_studio/ui/flows/canvas/node_model.dart';
import 'package:api_flow_studio/ui/flows/canvas/wire_geometry.dart';
import 'package:api_flow_studio/ui/flows/step_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const login = Endpoint(id: 'e-login', groupId: 'g', name: 'Login', method: 'POST', url: '/login');
  const me = Endpoint(
    id: 'e-me',
    groupId: 'g',
    name: 'Me',
    method: 'GET',
    url: '{{base_url}}/users/{{user_id}}?s={{status_code}}&n={{name}}',
  );

  StepResponse json(Object body) => StepResponse(source: StepResponseSource.history, isJson: true, body: body);

  List<NodeModel> nodes(Flow flow, {StepResponse? loginResponse}) => [
        buildNodeModel(
          flow: flow,
          index: 0,
          endpoint: login,
          response: loginResponse,
          environmentVariables: const {'base_url': 'h'},
          sessionAttachAuth: true,
        ),
        buildNodeModel(
          flow: flow,
          index: 1,
          endpoint: me,
          response: null,
          environmentVariables: const {'base_url': 'h'},
          sessionAttachAuth: true,
        ),
      ];

  test('a wire goes from the field pin to the input pin', () {
    const flow = Flow(id: 'f', name: 'F', steps: [
      FlowStep(endpointId: 'e-login', extract: {'user_id': 'response.body.user.id'}),
      FlowStep(endpointId: 'e-me'),
    ]);
    final models = nodes(flow, loginResponse: json({'token': 't', 'user': {'id': 'u1'}}));

    final wire = computeWires(models).single;

    expect((wire.fromStep, wire.toStep, wire.variable), (0, 1, 'user_id'));
    expect(wire.from, fieldPinOffset(models[0], 1));
    expect(wire.to, inputPinOffset(models[1], 1)); // base_url is row 0
    expect(wire.from, Offset(nodeLeft(0) + nodeWidth, canvasPadding + fieldRowCenterY(models[0].inputs.length, 1)));
    expect(wire.suggestion, isFalse);
  });

  test('an extract whose path is not a visible field starts at the header anchor', () {
    const flow = Flow(id: 'f', name: 'F', steps: [
      FlowStep(endpointId: 'e-login', extract: {'status_code': 'response.status', 'name': 'response.body.k11'}),
      FlowStep(endpointId: 'e-me'),
    ]);
    final models = nodes(flow, loginResponse: json({for (var i = 0; i < 12; i++) 'k$i': i}));

    final wires = computeWires(models);

    expect(wires, hasLength(2));
    for (final wire in wires) {
      expect(wire.from, headerAnchor(models[0]), reason: wire.variable);
    }
  });

  test('an extract without any response starts at the header anchor', () {
    const flow = Flow(id: 'f', name: 'F', steps: [
      FlowStep(endpointId: 'e-login', extract: {'user_id': 'response.body.id'}),
      FlowStep(endpointId: 'e-me'),
    ]);

    expect(computeWires(nodes(flow)).single.from, headerAnchor(nodes(flow)[0]));
  });

  test('inputs fed by env, session or generated values have no wire', () {
    const flow = Flow(id: 'f', name: 'F', steps: [FlowStep(endpointId: 'e-login'), FlowStep(endpointId: 'e-me')]);

    expect(computeWires(nodes(flow)), isEmpty);
  });
}
