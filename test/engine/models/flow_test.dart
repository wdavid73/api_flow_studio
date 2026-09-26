import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Flow', () {
    test('round-trips an ordered list of steps through JSON', () {
      const flow = Flow(
        id: 'f-1',
        name: 'User Registration Flow',
        steps: [
          FlowStep(endpointId: 'e-check-user', extract: {'exists': 'response.body.exists'}),
          FlowStep(endpointId: 'e-send-otp'),
          FlowStep(endpointId: 'e-validate-otp', extract: {'otp_token': 'response.body.token'}),
        ],
      );

      final decoded = Flow.fromJson(flow.toJson());

      expect(decoded, flow);
      expect(decoded.steps, hasLength(3));
    });
  });
}
