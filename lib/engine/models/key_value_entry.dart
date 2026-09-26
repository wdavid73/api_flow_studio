import 'package:freezed_annotation/freezed_annotation.dart';

part 'key_value_entry.freezed.dart';
part 'key_value_entry.g.dart';

@freezed
class KeyValueEntry with _$KeyValueEntry {
  const factory KeyValueEntry({
    required String key,
    required String value,
    @Default(true) bool enabled,
  }) = _KeyValueEntry;

  factory KeyValueEntry.fromJson(Map<String, dynamic> json) =>
      _$KeyValueEntryFromJson(json);
}
