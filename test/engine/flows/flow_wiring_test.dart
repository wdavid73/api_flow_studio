import 'package:api_flow_studio/engine/flows/flow_wiring.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const login = Endpoint(id: 'e-login', groupId: 'g', name: 'Login', method: 'POST', url: '/login');
  const me = Endpoint(id: 'e-me', groupId: 'g', name: 'Me', method: 'GET', url: '/users/{{user_id}}');
  const orders = Endpoint(id: 'e-orders', groupId: 'g', name: 'Orders', method: 'GET', url: '/orders?u={{user_id}}');
  final endpoints = {login.id: login, me.id: me, orders.id: orders};

  const flow = Flow(
    id: 'f',
    name: 'F',
    steps: [
      FlowStep(endpointId: 'e-login', extract: {'user_id': 'response.body.id', 'token': 'response.body.token'}),
      FlowStep(endpointId: 'e-me', extract: {'name': 'response.body.name'}),
      FlowStep(endpointId: 'e-orders'),
    ],
  );

  test('connectField sets the extract on the source step, replacing another path', () {
    final result = connectField(flow, fromStep: 0, path: 'response.body.user.id', toStep: 1, variable: 'user_id');

    expect(
      result,
      isA<Connected>().having(
        (c) => c.step.extract,
        'extract',
        {'user_id': 'response.body.user.id', 'token': 'response.body.token'},
      ),
    );
  });

  test('connectField adds a new name next to the existing ones', () {
    final result = connectField(flow, fromStep: 1, path: 'response.body.region', toStep: 2, variable: 'region');

    expect((result as Connected).step.extract, {'name': 'response.body.name', 'region': 'response.body.region'});
  });

  test('connectField is Shadowed when a step in between extracts the same name', () {
    const shadowing = Flow(
      id: 'f',
      name: 'F',
      steps: [
        FlowStep(endpointId: 'e-login'),
        FlowStep(endpointId: 'e-me', extract: {'user_id': 'response.body.other'}),
        FlowStep(endpointId: 'e-orders'),
      ],
    );

    expect(
      connectField(shadowing, fromStep: 0, path: 'response.body.id', toStep: 2, variable: 'user_id'),
      isA<Shadowed>().having((s) => s.stepIndex, 'stepIndex', 1),
    );
  });

  test('disconnectVariable removes only that extract', () {
    expect(disconnectVariable(flow, fromStep: 0, variable: 'user_id').extract, {'token': 'response.body.token'});
  });

  test('consumersOf counts later steps whose origin is that step', () {
    expect(consumersOf(flow, endpoints, const {}, fromStep: 0, variable: 'user_id'), 2);
    expect(consumersOf(flow, endpoints, const {}, fromStep: 0, variable: 'token'), 0);
  });
}
