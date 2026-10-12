import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/storage/key_value_backend.dart';
import '../l10n/locale_provider.dart';
import 'app_toast.dart';

/// The handler for errors nobody caught: when it is [StorageFullException] (the browser has no
/// room for what was being saved) it says so in a toast, in the current language, and the error
/// is dealt with; any other error is left to the default handling.
///
/// Many writes are started without anyone waiting on them (each keystroke of a rename), so the
/// failure has nowhere to go but here.
bool Function(Object error, StackTrace stack) storageFullHandler(ProviderContainer container) {
  return (error, stack) {
    if (error is! StorageFullException) return false;
    container.read(toastProvider.notifier).show(l10nFor(container.read(localeProvider)).storageFull);
    return true;
  };
}
