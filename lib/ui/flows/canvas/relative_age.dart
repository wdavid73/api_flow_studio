import 'package:flutter/widgets.dart';

import '../../../l10n/l10n.dart';

/// How long ago [at] was, in the largest whole unit: "just now", "5 min ago",
/// "3 h ago", "2 days ago".
String relativeAge(BuildContext context, DateTime at, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(at);
  final l10n = context.l10n;
  if (age.inMinutes < 1) return l10n.ageJustNow;
  if (age.inHours < 1) return l10n.ageMinutes(age.inMinutes);
  if (age.inDays < 1) return l10n.ageHours(age.inHours);
  return l10n.ageDays(age.inDays);
}
