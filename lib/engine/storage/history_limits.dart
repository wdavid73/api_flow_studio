import 'dart:convert';

import '../models/history_entry.dart';

/// Most bytes of a response body kept in the history (100 KB).
const int maxHistoryBodyBytes = 100 * 1024;

/// Most entries kept per request.
const int maxHistoryEntriesPerEndpoint = 20;

/// Most entries kept in a whole project, across all its requests.
const int maxHistoryEntriesPerProject = 500;

/// [text] cut to at most [maxBytes] bytes of UTF-8, never in the middle of a
/// character (nor of a surrogate pair), and whether anything was cut.
({String text, bool truncated}) truncateToBytes(String text, int maxBytes) {
  final bytes = utf8.encode(text);
  if (bytes.length <= maxBytes) return (text: text, truncated: false);

  // Step back to the start of a character: continuation bytes are 10xxxxxx.
  var end = maxBytes;
  while (end > 0 && (bytes[end] & 0xC0) == 0x80) {
    end--;
  }
  return (text: utf8.decode(bytes.sublist(0, end)), truncated: true);
}

/// [entry] with its body cut to [maxHistoryBodyBytes] and flagged when it was.
HistoryEntry limitedEntry(HistoryEntry entry) {
  final body = entry.body;
  if (body == null) return entry;
  final cut = truncateToBytes(body, maxHistoryBodyBytes);
  if (!cut.truncated) return entry;
  return entry.copyWith(body: cut.text, truncated: true);
}

/// The history of a project kept within the limits: each body truncated, at most
/// [perEndpoint] entries per request and [perProject] in total, dropping the
/// oldest first. Entries keep their order inside each request.
Map<String, List<HistoryEntry>> enforceHistoryLimits(
  Map<String, List<HistoryEntry>> history, {
  int perEndpoint = maxHistoryEntriesPerEndpoint,
  int perProject = maxHistoryEntriesPerProject,
}) {
  final trimmed = <String, List<HistoryEntry>>{
    for (final e in history.entries)
      e.key: [
        for (final entry in (e.value.length > perEndpoint ? e.value.sublist(e.value.length - perEndpoint) : e.value))
          limitedEntry(entry),
      ],
  };

  final total = trimmed.values.fold<int>(0, (sum, list) => sum + list.length);
  if (total <= perProject) return trimmed;

  // Drop the oldest entries across all requests until the total fits.
  final all = [for (final list in trimmed.values) ...list]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final dropped = {for (final entry in all.take(total - perProject)) entry.id};
  return {
    for (final e in trimmed.entries)
      if (e.value.any((entry) => !dropped.contains(entry.id)))
        e.key: [for (final entry in e.value) if (!dropped.contains(entry.id)) entry],
  };
}
