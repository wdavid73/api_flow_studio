import 'package:api_flow_studio/engine/flows/response_fields.dart';
import 'package:api_flow_studio/engine/flows/variable_naming.dart';
import 'package:flutter_test/flutter_test.dart';

ResponseField field(String path) => ResponseField(path: path, preview: '"x"');

void main() {
  test('suggestVariableName', () {
    expect(suggestVariableName('response.body.user.id'), 'user_id');
    expect(suggestVariableName('response.body.data.token'), 'token');
    expect(suggestVariableName('response.body.access_token'), 'access_token');
    expect(suggestVariableName('response.body.userId'), 'user_id');
    expect(suggestVariableName('response.body.items.0.id'), 'items_id');
    expect(suggestVariableName('response.body.id'), 'id');
    expect(suggestVariableName('response.status'), 'status');
  });

  test('suggestVariableName always gives a name the interpolator can resolve', () {
    expect(suggestVariableName('response.headers.content-type'), 'content_type');
    expect(suggestVariableName('response.body.userProfile.id'), 'user_profile_id');
  });

  test('suggestConnection matches normalized names and prefers the nearest step', () {
    final fields = {
      0: [field('response.body.user.id')],
      2: [field('response.body.data.userId')],
    };

    expect(
      suggestConnection(name: 'user_id', stepIndex: 3, fieldsByStep: fields),
      (stepIndex: 2, path: 'response.body.data.userId'),
    );
  });

  test('suggestConnection joins the last two segments', () {
    final fields = {
      0: [field('response.body.user.name'), field('response.body.user.id')],
    };

    expect(
      suggestConnection(name: 'user_id', stepIndex: 1, fieldsByStep: fields),
      (stepIndex: 0, path: 'response.body.user.id'),
    );
  });

  test('suggestConnection ignores the step itself and later steps, and returns null without a match', () {
    final fields = {
      1: [field('response.body.region')],
      2: [field('response.body.region')],
    };

    expect(suggestConnection(name: 'region', stepIndex: 1, fieldsByStep: fields), isNull);
    expect(suggestConnection(name: 'plan', stepIndex: 3, fieldsByStep: fields), isNull);
  });

  test('isValidVariableName', () {
    expect(isValidVariableName('user_id'), isTrue);
    expect(isValidVariableName('UserId2'), isTrue);
    for (final name in ['', 'user id', 'user-id', '{{x}}', ' id']) {
      expect(isValidVariableName(name), isFalse, reason: name);
    }
  });
}
