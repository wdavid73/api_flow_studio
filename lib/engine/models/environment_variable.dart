import 'package:freezed_annotation/freezed_annotation.dart';

part 'environment_variable.freezed.dart';
part 'environment_variable.g.dart';

@freezed
class EnvironmentVariable with _$EnvironmentVariable {
  const factory EnvironmentVariable({
    required String value,
    @Default(false) bool secret,
  }) = _EnvironmentVariable;

  factory EnvironmentVariable.fromJson(Map<String, dynamic> json) =>
      _$EnvironmentVariableFromJson(json);
}
