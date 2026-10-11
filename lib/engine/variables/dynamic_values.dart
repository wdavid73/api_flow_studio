import 'dart:math';

import 'package:uuid/uuid.dart';

const String _alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// Generates the values behind `{{$name}}` tokens. [random] and [now] are
/// injectable so tests are deterministic; by default they are a secure RNG
/// and the system clock.
///
/// Every call to [generate] produces a fresh value, so two `{{$uuid}}` tokens
/// in the same request never share one.
class DynamicValues {
  DynamicValues({Random? random, DateTime Function()? now})
      : _random = random ?? Random.secure(),
        _now = now ?? DateTime.now;

  final Random _random;
  final DateTime Function() _now;

  /// The token names (without the `$`) that [generate] understands.
  static const Set<String> names = {
    'uuid',
    'timestamp',
    'isoTimestamp',
    'randomInt',
    'randomString',
    'randomEmail',
  };

  static bool isKnown(String name) => names.contains(name);

  /// A fresh value for [name] (without the `$`), or `null` if it is unknown.
  String? generate(String name) => switch (name) {
        'uuid' => const Uuid().v4(),
        'timestamp' => (_now().millisecondsSinceEpoch ~/ 1000).toString(),
        'isoTimestamp' => _now().toUtc().toIso8601String(),
        'randomInt' => _random.nextInt(1000000).toString(),
        'randomString' => _randomString(12),
        'randomEmail' => 'test.${_randomString(8)}@example.com',
        _ => null,
      };

  String _randomString(int length) => String.fromCharCodes([
        for (var i = 0; i < length; i++)
          _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
      ]);
}
