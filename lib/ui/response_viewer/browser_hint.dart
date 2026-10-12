import '../../l10n/app_localizations.dart';

/// A line to add under a failed request when the app runs in a web page, or null on the desktop
/// (where the same failure has no browser rules behind it).
///
/// A page cannot tell why the browser stopped a request: a blocked cross-origin call (CORS), an
/// `http://` address from an `https` page (mixed content) and a server that is down all look the
/// same, a network error. So this is a pointer to the likely cause, not a diagnosis: mixed
/// content when the address is plain `http://` and not the local machine, CORS otherwise.
String? browserNetworkHint(AppLocalizations l10n, {required bool isBrowser, String? url}) {
  if (!isBrowser) return null;
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri != null && uri.scheme == 'http' && !_isLocal(uri.host)) return l10n.browserHintMixedContent;
  return l10n.browserHintCors;
}

/// The browser lets an `https` page call these over plain `http://`.
bool _isLocal(String host) => host == 'localhost' || host == '127.0.0.1' || host == '[::1]' || host == '::1' || host.endsWith('.localhost');
