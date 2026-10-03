import 'package:api_flow_studio/ui/history/day_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 2, 15, 30);

  test('the same calendar day is TODAY, whatever the hour', () {
    expect(dayLabel(DateTime(2026, 10, 2, 0, 1), now), 'TODAY');
    expect(dayLabel(DateTime(2026, 10, 2, 23, 59), now), 'TODAY');
  });

  test('the previous calendar day is YESTERDAY', () {
    expect(dayLabel(DateTime(2026, 10, 1, 23, 59), now), 'YESTERDAY');
    expect(dayLabel(DateTime(2026, 10, 1, 0, 0), now), 'YESTERDAY');
  });

  test('anything older is its ISO date with zero padding', () {
    expect(dayLabel(DateTime(2026, 9, 30, 12), now), '2026-09-30');
    expect(dayLabel(DateTime(2026, 1, 5, 12), now), '2026-01-05');
  });

  test('a month boundary still counts as yesterday', () {
    expect(dayLabel(DateTime(2026, 9, 30, 8), DateTime(2026, 10, 1, 9)), 'YESTERDAY');
  });

  test('formatTime is zero-padded HH:mm', () {
    expect(formatTime(DateTime(2026, 10, 2, 7, 5)), '07:05');
    expect(formatTime(DateTime(2026, 10, 2, 23, 59)), '23:59');
  });
}
