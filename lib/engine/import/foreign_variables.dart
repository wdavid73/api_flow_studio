import '../models/models.dart';
import 'import_result.dart';

final RegExp _token = RegExp(r'\{\{(\w+)\}\}');

/// One warning for each `{{name}}` the imported requests use that [defined] (the variables
/// the import creates) does not have, where it is first used.
///
/// A file is somebody else's text, and `{{name}}` is resolved when the request is sent: a
/// value like `{{token}}` takes whatever variable of the same name the person has. That is
/// often what they want (a collection that expects their environment), and sometimes a way
/// to send a secret to a server the file chose, so it is said. Generated values
/// (`{{$uuid}}`) are built in and are not reported.
List<ImportWarning> undefinedVariableWarnings(List<Endpoint> endpoints, Set<String> defined) {
  final firstUse = <String, String>{};

  void scan(String name, String? text) {
    if (text == null) return;
    for (final match in _token.allMatches(text)) {
      final variable = match[1]!;
      if (!defined.contains(variable)) firstUse.putIfAbsent(variable, () => name);
    }
  }

  for (final endpoint in endpoints) {
    final at = endpoint.name;
    scan(at, endpoint.url);
    for (final entry in [...endpoint.headers, ...endpoint.queryParams]) {
      if (!entry.enabled) continue;
      scan(at, entry.key);
      scan(at, entry.value);
    }
    endpoint.body.map(
      none: (_) {},
      json: (body) => scan(at, body.raw),
      formUrlEncoded: (body) {
        for (final entry in body.fields.where((f) => f.enabled)) {
          scan(at, entry.key);
          scan(at, entry.value);
        }
      },
      multipart: (body) {
        for (final field in body.fields.where((f) => f.enabled)) {
          scan(at, field.name);
          scan(at, field.value);
        }
      },
    );
    endpoint.authConfig.map(
      none: (_) {},
      basic: (auth) {
        scan(at, auth.username);
        scan(at, auth.password);
      },
      bearer: (auth) => scan(at, auth.token),
    );
  }

  return [
    for (final entry in firstUse.entries)
      ImportWarning(
        where: entry.value,
        message: '{{${entry.key}}} is not defined by this file; when the request is sent it takes the value of '
            'a variable of yours with that name, if there is one',
      ),
  ];
}
