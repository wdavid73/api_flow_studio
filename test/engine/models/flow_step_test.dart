import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlowStep', () {
    test('defaults stopOnFailure to true and extract to empty', () {
      const step = FlowStep(endpointId: 'e-1');

      expect(step.stopOnFailure, isTrue);
      expect(step.extract, isEmpty);
    });

    test('round-trips extract mapping and assertion through JSON', () {
      const step = FlowStep(
        endpointId: 'e-1',
        extract: {'user_id': 'response.body.data.id'},
        assertField: 'response.status',
        assertExpected: '201',
        stopOnFailure: false,
      );

      expect(FlowStep.fromJson(step.toJson()), step);
    });
  });
}
