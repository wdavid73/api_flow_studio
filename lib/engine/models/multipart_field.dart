import 'package:freezed_annotation/freezed_annotation.dart';

part 'multipart_field.freezed.dart';
part 'multipart_field.g.dart';

enum MultipartFieldKind { text, file }

/// One part of a `multipart/form-data` body.
@freezed
class MultipartField with _$MultipartField {
  const factory MultipartField({
    required String name,
    @Default(MultipartFieldKind.text) MultipartFieldKind kind,

    /// The text itself, or the path of the file for a [MultipartFieldKind.file].
    @Default('') String value,

    /// For files only; null means "work it out from the file extension".
    String? contentType,
    @Default(true) bool enabled,
  }) = _MultipartField;

  factory MultipartField.fromJson(Map<String, dynamic> json) => _$MultipartFieldFromJson(json);
}
