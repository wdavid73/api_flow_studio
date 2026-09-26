import 'package:freezed_annotation/freezed_annotation.dart';

import 'auth_config.dart';
import 'key_value_entry.dart';
import 'request_body.dart';

part 'endpoint.freezed.dart';
part 'endpoint.g.dart';

@freezed
class Endpoint with _$Endpoint {
  const factory Endpoint({
    required String id,
    required String groupId,
    required String name,
    required String method,
    required String url,
    @Default([]) List<KeyValueEntry> headers,
    @Default([]) List<KeyValueEntry> queryParams,
    @Default(RequestBody.none()) RequestBody body,
    @Default(AuthConfig.none()) AuthConfig authConfig,
  }) = _Endpoint;

  factory Endpoint.fromJson(Map<String, dynamic> json) =>
      _$EndpointFromJson(json);
}
