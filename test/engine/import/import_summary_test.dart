import 'package:api_flow_studio/engine/import/import_result.dart';
import 'package:flutter_test/flutter_test.dart';

ImportSummary summary({
  String source = 'Postman collection',
  int folders = 0,
  int requests = 0,
  int environments = 0,
  int valuesToFill = 0,
  List<ImportWarning> warnings = const [],
}) =>
    ImportSummary(
      source: source,
      folders: folders,
      requests: requests,
      environments: environments,
      valuesToFill: valuesToFill,
      warnings: warnings,
    );

void main() {
  group('ImportSummary.describe', () {
    test('counts requests and folders', () {
      expect(summary(requests: 12, folders: 4).describe(), 'Imported Postman collection: 12 requests in 4 folders');
    });

    test('uses the singular for one', () {
      expect(summary(requests: 1, folders: 1).describe(), 'Imported Postman collection: 1 request in 1 folder');
    });

    test('adds the environments', () {
      expect(summary(requests: 2, folders: 1, environments: 1).describe(), 'Imported Postman collection: 2 requests in 1 folder, 1 environment');
      expect(summary(requests: 2, folders: 1, environments: 3).describe(), endsWith(', 3 environments'));
    });

    test('says what is left to fill in', () {
      expect(summary(requests: 2, folders: 1, valuesToFill: 1).describe(), endsWith(' — 1 value to fill in'));
      expect(summary(requests: 2, folders: 1, valuesToFill: 2).describe(), endsWith(' — 2 values to fill in'));
    });

    test('a file with only environments says just that', () {
      expect(summary(source: 'Postman environment', environments: 1).describe(), 'Imported Postman environment: 1 environment');
    });

    test('does not mention the warnings (they have their own list)', () {
      final text = summary(requests: 1, folders: 1, warnings: const [ImportWarning(where: 'a', message: 'b')]).describe();

      expect(text, 'Imported Postman collection: 1 request in 1 folder');
    });
  });

  test('ImportResult has no data by default', () {
    const result = ImportResult(source: 'x');

    expect(result.groups, isEmpty);
    expect(result.endpoints, isEmpty);
    expect(result.environments, isEmpty);
    expect(result.warnings, isEmpty);
  });
}
