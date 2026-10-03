import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Clock used for the expiry label. Overridden in tests.
final sessionClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
