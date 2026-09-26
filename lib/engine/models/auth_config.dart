import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_config.freezed.dart';
part 'auth_config.g.dart';

@freezed
class AuthConfig with _$AuthConfig {
  const factory AuthConfig.none() = AuthConfigNone;

  const factory AuthConfig.basic({
    required String username,
    required String password,
  }) = AuthConfigBasic;

  const factory AuthConfig.bearer({required String token}) = AuthConfigBearer;

  factory AuthConfig.fromJson(Map<String, dynamic> json) =>
      _$AuthConfigFromJson(json);
}
