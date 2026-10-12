import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';

/// A single-entry placeholder timeline ("request sent -> response
/// received, Xms"). A full network waterfall (DNS/TLS/TTFB breakdown) is
/// out of MVP scope.
class ResponseTimelineTab extends StatelessWidget {
  const ResponseTimelineTab({super.key, required this.elapsedMs});

  final int elapsedMs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(context.l10n.responseTimeline(elapsedMs)),
    );
  }
}
