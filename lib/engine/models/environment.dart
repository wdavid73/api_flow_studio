import 'package:freezed_annotation/freezed_annotation.dart';

import 'environment_variable.dart';

part 'environment.freezed.dart';
part 'environment.g.dart';

@freezed
class Environment with _$Environment {
  const Environment._();

  const factory Environment({
    required String id,
    required String name,
    @Default({}) Map<String, EnvironmentVariable> variables,
  }) = _Environment;

  factory Environment.fromJson(Map<String, dynamic> json) =>
      _$EnvironmentFromJson(json);

  /// Flattens [variables] to a plain key -> value map for interpolation,
  /// regardless of each variable's `secret` flag.
  Map<String, String> get resolvedVariables => {
        for (final entry in variables.entries) entry.key: entry.value.value,
      };
}
