import '../models/models.dart';
import '../variables/interpolator.dart' show generatedTokenPattern, variableTokenPattern;

/// What a step's request reads from outside itself: the `{{name}}` variables
/// it needs a value for, and the generated tokens (`{{$uuid}}`…) that fill
/// themselves in when it is sent.
class StepInputs {
  const StepInputs({required this.variables, required this.generated});

  /// Variable names, in the order they first appear, without duplicates.
  final List<String> variables;

  /// Generated-token names without the `$` (`uuid`, `randomEmail`), in the
  /// order they first appear, without duplicates.
  final List<String> generated;
}

/// The inputs of [endpoint], read from everything that is sent: the url, the
/// enabled query params and headers (key and value), the body and the
/// authentication. Disabled entries are skipped because they are never sent,
/// so a value for them is never needed.
StepInputs stepInputs(Endpoint endpoint) {
  final variables = <String>{};
  final generated = <String>{};

  void read(String text) {
    for (final match in variableTokenPattern.allMatches(text)) {
      variables.add(match.group(1)!);
    }
    for (final match in generatedTokenPattern.allMatches(text)) {
      generated.add(match.group(1)!);
    }
  }

  void readEntries(List<KeyValueEntry> entries) {
    for (final entry in entries.where((e) => e.enabled)) {
      read(entry.key);
      read(entry.value);
    }
  }

  read(endpoint.url);
  readEntries(endpoint.queryParams);
  readEntries(endpoint.headers);
  endpoint.body.map(
    none: (_) {},
    json: (b) => read(b.raw),
    formUrlEncoded: (b) => readEntries(b.fields),
    multipart: (b) {
      for (final field in b.fields.where((f) => f.enabled)) {
        read(field.name);
        read(field.value);
        read(field.contentType ?? '');
      }
    },
  );
  endpoint.authConfig.map(
    none: (_) {},
    basic: (a) {
      read(a.username);
      read(a.password);
    },
    bearer: (a) => read(a.token),
  );

  return StepInputs(variables: variables.toList(), generated: generated.toList());
}
