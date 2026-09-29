import 'dart:convert';
import 'dart:io';

import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// The repo-root `sample-endpoints.json` ships inside the Windows/macOS
/// release zips (see `.github/workflows/release.yml`) so a freshly
/// downloaded build has something to Import right away. This guards it
/// against silently rotting if the Group/Endpoint JSON shape ever changes.
void main() {
  test('sample-endpoints.json parses as a valid collections file', () {
    final decoded = jsonDecode(File('sample-endpoints.json').readAsStringSync()) as Map<String, dynamic>;

    final groups =
        (decoded['groups'] as List).map((e) => Group.fromJson(e as Map<String, dynamic>)).toList();
    final endpoints = (decoded['endpoints'] as List)
        .map((e) => Endpoint.fromJson(e as Map<String, dynamic>))
        .toList();

    expect(groups, isNotEmpty);
    expect(endpoints, isNotEmpty);

    final groupIds = groups.map((g) => g.id).toSet();
    for (final group in groups) {
      if (group.parentGroupId != null) {
        expect(groupIds, contains(group.parentGroupId), reason: '${group.name} has a dangling parent');
      }
    }
    for (final endpoint in endpoints) {
      expect(groupIds, contains(endpoint.groupId), reason: '${endpoint.name} has a dangling group');
    }
  });
}
