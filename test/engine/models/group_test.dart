import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Group', () {
    test('root group has a null parentGroupId', () {
      const group = Group(id: 'g-1', name: 'Authentication API');

      expect(group.parentGroupId, isNull);
    });

    test('round-trips a nested group through JSON', () {
      const group = Group(
        id: 'g-2',
        name: 'User Service',
        parentGroupId: 'g-1',
        order: 3,
      );

      expect(Group.fromJson(group.toJson()), group);
    });
  });
}
