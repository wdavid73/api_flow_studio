import 'dart:math';

import 'package:api_flow_studio/engine/variables/dynamic_values.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedNow = DateTime.utc(2026, 10, 11, 14, 3, 22);

  DynamicValues build() =>
      DynamicValues(random: Random(42), now: () => fixedNow);

  group('DynamicValues.generate', () {
    test('uuid is a v4 UUID and differs on every call', () {
      final values = build();
      final a = values.generate('uuid')!;
      final b = values.generate('uuid')!;
      final v4 = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      expect(a, matches(v4));
      expect(b, matches(v4));
      expect(a, isNot(b));
    });

    test('timestamp is epoch seconds', () {
      expect(build().generate('timestamp'), '1791727402');
    });

    test('isoTimestamp is ISO-8601 in UTC', () {
      expect(build().generate('isoTimestamp'), '2026-10-11T14:03:22.000Z');
    });

    test('isoTimestamp converts a local clock to UTC', () {
      final values = DynamicValues(
        random: Random(1),
        now: () => DateTime.fromMillisecondsSinceEpoch(1791727402000),
      );
      expect(values.generate('isoTimestamp'), '2026-10-11T14:03:22.000Z');
    });

    test('randomInt is an integer between 0 and 999999', () {
      final values = build();
      for (var i = 0; i < 200; i++) {
        final n = int.parse(values.generate('randomInt')!);
        expect(n, inInclusiveRange(0, 999999));
      }
    });

    test('randomString is 12 lowercase alphanumeric characters', () {
      final values = build();
      final a = values.generate('randomString')!;
      expect(a, matches(RegExp(r'^[a-z0-9]{12}$')));
      expect(values.generate('randomString'), isNot(a));
    });

    test('randomEmail is test.<8 chars>@example.com', () {
      final values = build();
      final a = values.generate('randomEmail')!;
      expect(a, matches(RegExp(r'^test\.[a-z0-9]{8}@example\.com$')));
      expect(values.generate('randomEmail'), isNot(a));
    });

    test('the same seed yields the same random values', () {
      expect(
        DynamicValues(random: Random(7)).generate('randomString'),
        DynamicValues(random: Random(7)).generate('randomString'),
      );
    });

    test('an unknown name returns null', () {
      expect(build().generate('nope'), isNull);
      expect(build().generate(''), isNull);
    });
  });

  group('DynamicValues.isKnown', () {
    test('is true for every name in DynamicValues.names and generates it', () {
      final values = build();
      for (final name in DynamicValues.names) {
        expect(DynamicValues.isKnown(name), isTrue, reason: name);
        expect(values.generate(name), isNotNull, reason: name);
      }
    });

    test('lists the six documented tokens', () {
      expect(DynamicValues.names, {
        'uuid',
        'timestamp',
        'isoTimestamp',
        'randomInt',
        'randomString',
        'randomEmail',
      });
    });

    test('is false for unknown names', () {
      expect(DynamicValues.isKnown('nope'), isFalse);
    });
  });
}
