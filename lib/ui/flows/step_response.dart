import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/flows/flow_step_result.dart';
import '../../engine/models/models.dart';
import '../history/history_provider.dart';
import 'flow_run_provider.dart';

enum StepResponseSource { run, history }

/// The last response the canvas knows for one step, and where it came from.
class StepResponse {
  const StepResponse({
    required this.source,
    this.at,
    this.status,
    this.headers = const {},
    this.body,
    this.isJson = false,
    this.truncated = false,
  });

  final StepResponseSource source;
  final DateTime? at;
  final int? status;
  final Map<String, String> headers;

  /// The decoded JSON (`Map`/`List`) when [isJson]; otherwise the raw text.
  final Object? body;
  final bool isJson;

  /// The history kept only the start of the body, so it is not decoded.
  final bool truncated;
}

typedef StepResponseKey = ({String flowId, int index, String endpointId});

/// The response a step shows: its result in this session's last run of the
/// flow when it got one, else the newest entry of its request's history that
/// has a body, else null.
final stepResponseProvider = Provider.family<AsyncValue<StepResponse?>, StepResponseKey>((ref, key) {
  final run = ref.watch(flowRunProvider(key.flowId));
  final result = key.index < run.results.length ? run.results[key.index] : null;
  final response = result?.status == FlowStepStatus.skipped ? null : result?.response;
  if (response != null && response.error == null) {
    final body = response.body;
    return AsyncData(StepResponse(
      source: StepResponseSource.run,
      at: key.index < run.resultAt.length ? run.resultAt[key.index] : null,
      status: response.status,
      headers: response.headers,
      body: body,
      isJson: body is Map || body is List,
    ));
  }
  return ref.watch(historyProvider(key.endpointId)).whenData(_fromHistory);
});

StepResponse? _fromHistory(List<HistoryEntry> entries) {
  // appendHistoryEntry adds at the end, so the newest entry is the last one.
  for (final entry in entries.reversed) {
    final body = entry.body;
    if (body == null) continue;
    final decoded = entry.truncated ? null : _tryDecode(body);
    return StepResponse(
      source: StepResponseSource.history,
      at: entry.timestamp,
      status: entry.status,
      headers: entry.headers,
      body: decoded ?? body,
      isJson: decoded != null,
      truncated: entry.truncated,
    );
  }
  return null;
}

Object? _tryDecode(String text) {
  try {
    final decoded = jsonDecode(text);
    return decoded is Map || decoded is List ? decoded : null;
  } on FormatException {
    return null;
  }
}
