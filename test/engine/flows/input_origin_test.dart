import 'package:api_flow_studio/engine/flows/input_origin.dart';
import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const flow = Flow(
    id: 'f',
    name: 'Sign up',
    steps: [
      FlowStep(endpointId: 'register', extract: {'email': 'response.body.data.email'}),
      FlowStep(endpointId: 'login', extract: {'user_id': 'response.body.user.id', 'email': 'response.body.email'}),
      FlowStep(endpointId: 'me'),
      FlowStep(endpointId: 'home'),
    ],
  );

  test('the nearest earlier step that extracts the name wins', () {
    expect(
      resolveInputOrigin(flow, 3, 'email', const {}),
      isA<FromStep>()
          .having((o) => o.stepIndex, 'stepIndex', 1)
          .having((o) => o.path, 'path', 'response.body.email'),
    );
  });

  test("a step's own extract does not feed its own inputs", () {
    expect(resolveInputOrigin(flow, 1, 'user_id', const {}), isA<Missing>());
  });

  test('an extracted value wins over the environment', () {
    expect(resolveInputOrigin(flow, 2, 'user_id', const {'user_id': 'x'}), isA<FromStep>());
  });

  test('falls back to the environment, then the session, then missing', () {
    expect(resolveInputOrigin(flow, 2, 'base_url', const {'base_url': 'h'}), isA<FromEnvironment>());
    expect(resolveInputOrigin(flow, 2, 'session_access_token', const {}), isA<FromSession>());
    expect(resolveInputOrigin(flow, 2, 'session_refresh_token', const {}), isA<FromSession>());
    expect(resolveInputOrigin(flow, 2, 'region', const {}), isA<Missing>());
  });

  test('the environment wins over a session variable of the same name', () {
    expect(
      resolveInputOrigin(flow, 2, 'session_access_token', const {'session_access_token': 'pasted'}),
      isA<FromEnvironment>(),
    );
  });

  test('the first step has only the environment and the session', () {
    expect(resolveInputOrigin(flow, 0, 'email', const {}), isA<Missing>());
  });
}
