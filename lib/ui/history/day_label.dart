import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// Heading for the day [timestamp] falls on, relative to [now]: `TODAY`,
/// `YESTERDAY`, or the ISO date (`2026-09-30`). Compares calendar days, not
/// 24-hour spans, and uses the local time of both.
String dayLabel(DateTime timestamp, DateTime now, {AppLocalizations? l10n}) {
  l10n ??= lookupAppLocalizations(const Locale('en'));
  final day = DateTime(timestamp.year, timestamp.month, timestamp.day);
  final today = DateTime(now.year, now.month, now.day);
  final daysAgo = today.difference(day).inDays;

  if (daysAgo == 0) return l10n.historyToday;
  if (daysAgo == 1) return l10n.historyYesterday;
  return '${day.year}-${_two(day.month)}-${_two(day.day)}';
}

/// Zero-padded `HH:mm`.
String formatTime(DateTime timestamp) => '${_two(timestamp.hour)}:${_two(timestamp.minute)}';

String _two(int value) => value.toString().padLeft(2, '0');
