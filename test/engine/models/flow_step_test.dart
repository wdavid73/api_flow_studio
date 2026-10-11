import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlowStep', () {
    test('defaults stopOnFailure to true, extract and assertions to empty', () {
      const step = FlowStep(endpointId: 'e-1');

      expect(step.stopOnFailure, isTrue);
      expect(step.extract, isEmpty);
      expect(step.assertions, isEmpty);
    });

    test('round-trips extract mapping and assertions through JSON', () {
      const step = FlowStep(
        endpointId: 'e-1',
        extract: {'user_id': 'response.body.data.id'},
        assertions: [
          Assertion(field: 'response.status', expected: '201'),
          Assertion(field: 'response.elapsedMs', operator: AssertionOperator.lessThan, expected: '800'),
        ],
        stopOnFailure: false,
      );

      expect(FlowStep.fromJson(step.toJson()), step);
    });

    test('toJson writes assertions and none of the legacy fields', () {
      const step = FlowStep(endpointId: 'e-1', assertions: [Assertion(field: 'response.status', expected: '200')]);

      final json = step.toJson();

      expect(json.containsKey('assertions'), isTrue);
      expect(json.containsKey('assertField'), isFalse);
      expect(json.containsKey('assertExpected'), isFalse);
    });
  });

  group('FlowStep.fromJson legacy assertion', () {
    Map<String, dynamic> legacy(Map<String, dynamic> extra) => {'endpointId': 'e-1', ...extra};

    test('assertField + assertExpected become one equals assertion', () {
      final step = FlowStep.fromJson(legacy({'assertField': 'response.status', 'assertExpected': '200'}));

      expect(step.assertions, [const Assertion(field: 'response.status', expected: '200')]);
    });

    test('only one of the two legacy fields creates nothing', () {
      expect(FlowStep.fromJson(legacy({'assertField': 'response.status'})).assertions, isEmpty);
      expect(FlowStep.fromJson(legacy({'assertExpected': '200'})).assertions, isEmpty);
    });

    test('empty legacy values create nothing', () {
      expect(FlowStep.fromJson(legacy({'assertField': '', 'assertExpected': ''})).assertions, isEmpty);
    });

    test('assertions present win over the legacy fields', () {
      final step = FlowStep.fromJson(legacy({
        'assertField': 'response.status',
        'assertExpected': '200',
        'assertions': [
          {'field': 'response.body.id', 'operator': 'exists', 'expected': ''},
        ],
      }));

      expect(step.assertions, [const Assertion(field: 'response.body.id', operator: AssertionOperator.exists)]);
    });

    test('a step with neither has no assertions', () {
      expect(FlowStep.fromJson(legacy({})).assertions, isEmpty);
    });
  });
}
