import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// Best-effort cookie display: [headers] already joins repeated
/// `Set-Cookie` values with ", " (see RequestExecutor), which isn't a
/// fully correct split when a cookie's own Expires attribute contains a
/// comma -- acceptable for an MVP display-only view, not a real cookie jar.
class ResponseCookiesTab extends StatelessWidget {
  const ResponseCookiesTab({super.key, required this.headers});

  final Map<String, String> headers;

  List<String> get _cookies {
    final entry = headers.entries
        .where((e) => e.key.toLowerCase() == 'set-cookie')
        .map((e) => e.value)
        .firstOrNull;
    if (entry == null || entry.isEmpty) return const [];
    return entry.split(', ');
  }

  @override
  Widget build(BuildContext context) {
    final cookies = _cookies;
    if (cookies.isEmpty) {
      return const Center(child: Text('No cookies'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: cookies.length,
      itemBuilder: (context, index) => Text(cookies[index], style: AppTypography.codeSm),
    );
  }
}
