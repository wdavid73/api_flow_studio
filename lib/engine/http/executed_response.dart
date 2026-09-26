import 'package:freezed_annotation/freezed_annotation.dart';

part 'executed_response.freezed.dart';

/// The outcome of running a request through [RequestExecutor]. [status] is
/// null only when the request never reached the server (a transport
/// failure, described by [error]) -- an HTTP error status like 404/500
/// still comes back as a normal, non-null [status] with [error] unset.
@freezed
class ExecutedResponse with _$ExecutedResponse {
  const factory ExecutedResponse({
    int? status,
    @Default({}) Map<String, String> headers,
    dynamic body,
    @Default(0) int elapsedMs,
    @Default(0) int sizeBytes,
    String? error,
  }) = _ExecutedResponse;
}
