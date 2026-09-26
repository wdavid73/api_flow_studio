import 'package:api_flow_studio/engine/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HistoryEntry', () {
    test('round-trips a successful response through JSON', () {
      final entry = HistoryEntry(
        id: 'h-1',
        endpointId: 'e-1',
        timestamp: DateTime.utc(2026, 1, 1, 12, 30),
        status: 200,
        headers: const {'content-type': 'application/json'},
        body: '{"status":"success"}',
        elapsedMs: 142,
      );

      expect(HistoryEntry.fromJson(entry.toJson()), entry);
    });

    test('round-trips a transport error with no status', () {
      final entry = HistoryEntry(
        id: 'h-2',
        endpointId: 'e-1',
        timestamp: DateTime.utc(2026, 1, 1, 12, 31),
        error: 'Connection refused',
      );

      final decoded = HistoryEntry.fromJson(entry.toJson());

      expect(decoded, entry);
      expect(decoded.status, isNull);
    });
  });
}
