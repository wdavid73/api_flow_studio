import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the place the app runs in can do. The browser cannot do some things the desktop apps
/// can; the screens ask this instead of checking the platform themselves, so tests can pretend
/// to be either.
class PlatformCapabilities {
  const PlatformCapabilities({required this.canSendLocalFiles, required this.canReadSetCookie});

  /// The desktop apps.
  static const desktop = PlatformCapabilities(canSendLocalFiles: true, canReadSetCookie: true);

  /// A web page: no access to paths on the computer, and `Set-Cookie` is hidden from scripts.
  static const browser = PlatformCapabilities(canSendLocalFiles: false, canReadSetCookie: false);

  /// A Form Data field can name a file on this computer and send it.
  final bool canSendLocalFiles;

  /// The response's `Set-Cookie` headers are visible to the app.
  final bool canReadSetCookie;

  bool get isBrowser => !canSendLocalFiles;
}

final platformCapabilitiesProvider = Provider<PlatformCapabilities>(
  (ref) => kIsWeb ? PlatformCapabilities.browser : PlatformCapabilities.desktop,
);
