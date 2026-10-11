import 'package:freezed_annotation/freezed_annotation.dart';

import 'key_value_entry.dart';
import 'multipart_field.dart';

part 'request_body.freezed.dart';
part 'request_body.g.dart';

@freezed
class RequestBody with _$RequestBody {
  const factory RequestBody.none() = RequestBodyNone;

  const factory RequestBody.json(String raw) = RequestBodyJson;

  const factory RequestBody.formUrlEncoded(List<KeyValueEntry> fields) =
      RequestBodyFormUrlEncoded;

  /// A `multipart/form-data` body: text parts and files.
  const factory RequestBody.multipart(List<MultipartField> fields) = RequestBodyMultipart;

  factory RequestBody.fromJson(Map<String, dynamic> json) =>
      _$RequestBodyFromJson(json);
}
