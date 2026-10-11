/// [base], or `base (2)`, `base (3)`… when [taken] already has it (ignoring case and
/// surrounding spaces). With [maxLength] the base is shortened to leave room for
/// the number, so the result still fits.
String uniqueName(String base, Iterable<String> taken, {int? maxLength}) {
  final used = {for (final name in taken) name.trim().toLowerCase()};
  if (!used.contains(base.trim().toLowerCase())) return base;

  for (var n = 2;; n++) {
    final suffix = ' ($n)';
    final room = maxLength == null ? base.length : maxLength - suffix.length;
    final candidate = '${base.length > room ? base.substring(0, room) : base}$suffix';
    if (!used.contains(candidate.trim().toLowerCase())) return candidate;
  }
}
