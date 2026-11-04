import 'package:api_flow_studio/engine/flows/input_origin.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:api_flow_studio/ui/flows/canvas/canvas_metrics.dart';
import 'package:api_flow_studio/ui/flows/canvas/node_model.dart';
import 'package:api_flow_studio/ui/flows/step_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const login = Endpoint(id: 'e-login', groupId: 'g', name: 'Login', method: 'POST', url: '/login');
  const me = Endpoint(
    id: 'e-me',
    groupId: 'g',
    name: 'Me',
    method: 'GET',
    url: '{{base_url}}/users/{{user_id}}?t={{\$timestamp}}',
  );
  const flow = Flow(
    id: 'f',
    name: 'F',
    steps: [
      FlowStep(endpointId: 'e-login', extract: {'user_id': 'response.body.user.id'}),
      FlowStep(endpointId: 'e-me'),
    ],
  );

  NodeModel model({
    int index = 1,
    Endpoint? endpoint = me,
    StepResponse? response,
    bool sessionAttachAuth = true,
  }) =>
      buildNodeModel(
        flow: flow,
        index: index,
        endpoint: endpoint,
        response: response,
        environmentVariables: const {'base_url': 'https://api.dev'},
        sessionAttachAuth: sessionAttachAuth,
      );

  test('orders variable rows, then generated, then the session row', () {
    final rows = model().inputs;

    expect(rows.map((r) => r.kind), [
      InputRowKind.variable,
      InputRowKind.variable,
      InputRowKind.generated,
      InputRowKind.session,
    ]);
    expect(rows.map((r) => r.label), ['base_url', 'user_id', '\$timestamp', 'Authorization']);
    expect(rows[0].origin, isA<FromEnvironment>());
    expect(rows[1].origin, const FromStep(0, 'response.body.user.id'));
  });

  test('adds the session row only when attachAuth is on and the request accepts the token', () {
    expect(model(sessionAttachAuth: false).inputs.any((r) => r.kind == InputRowKind.session), isFalse);

    const withAuth = Endpoint(
      id: 'e-me',
      groupId: 'g',
      name: 'Me',
      method: 'GET',
      url: '/me',
      authConfig: AuthConfig.bearer(token: 'mine'),
    );
    expect(model(endpoint: withAuth).inputs.any((r) => r.kind == InputRowKind.session), isFalse);
  });

  test('a step with no inputs gets one none row', () {
    final rows = model(index: 0, endpoint: login, sessionAttachAuth: false).inputs;

    expect(rows.single.kind, InputRowKind.none);
  });

  test('shows at most 8 fields and counts the hidden ones', () {
    final m = model(
      response: StepResponse(
        source: StepResponseSource.history,
        isJson: true,
        body: {for (var i = 0; i < 11; i++) 'k$i': i},
      ),
    );

    expect(m.visibleFields, hasLength(maxVisibleFields));
    expect(m.hiddenFieldCount, 3);
    expect(m.responseRowCount, maxVisibleFields + 1);
  });

  test('a response that is not JSON has no fields but one message row', () {
    final m = model(response: const StepResponse(source: StepResponseSource.history, body: '<html>'));

    expect(m.fields, isNull);
    expect(m.visibleFields, isEmpty);
    expect(m.responseRowCount, 1);
  });

  test('a missing endpoint gives a none row and no fields', () {
    final m = model(endpoint: null);

    expect(m.inputs.single.kind, InputRowKind.none);
    expect(m.fields, isNull);
    expect(m.hasResponse, isFalse);
  });

  test('the height follows the metrics', () {
    final m = model();

    expect(m.height, nodeHeight(4, 0, hasResponse: false));
  });
}
