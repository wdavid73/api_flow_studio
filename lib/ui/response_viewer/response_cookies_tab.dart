import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_typography.dart';
import '../../l10n/l10n.dart';
import '../platform/platform_capabilities.dart';

/// Best-effort cookie display: [headers] already joins repeated
/// `Set-Cookie` values with ", " (see RequestExecutor), which isn't a
/// fully correct split when a cookie's own Expires attribute contains a
/// comma -- acceptable for an MVP display-only view, not a real cookie jar.
class ResponseCookiesTab extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final cookies = _cookies;
    if (cookies.isEmpty) {
      // A web page cannot read Set-Cookie, so "none" would be a lie there.
      final hidden = !ref.watch(platformCapabilitiesProvider).canReadSetCookie;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            hidden ? context.l10n.responseCookiesHiddenInBrowser : context.l10n.responseNoCookies,
            key: hidden ? const Key('cookies-hidden-in-browser') : null,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: cookies.length,
      itemBuilder: (context, index) => Text(cookies[index], style: AppTypography.codeSm),
    );
  }
}
