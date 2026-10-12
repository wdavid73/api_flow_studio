import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/storage/json_store.dart';
import '../../l10n/app_localizations.dart';

/// The languages the app has texts for, each named in itself (a language is always
/// shown in its own words, so someone who cannot read the current one can still find theirs).
const List<({Locale locale, String name})> appLanguages = [
  (locale: Locale('en'), name: 'English'),
  (locale: Locale('es'), name: 'Español'),
];

/// The language saved from the last run (null: follow the system). `main` overrides it
/// after reading the settings file.
final initialLocaleProvider = Provider<Locale?>((ref) => null);

/// Where the choice is saved. Null (the default, used by tests) keeps it in memory only.
final appSettingsStoreProvider = Provider<JsonStore?>((ref) => null);

/// The language the app shows: null follows the system language (falling back to English
/// when the system's is not one of [AppLocalizations.supportedLocales]).
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() => ref.read(initialLocaleProvider);

  Future<void> select(Locale? locale) async {
    state = locale;
    try {
      await ref
          .read(appSettingsStoreProvider)
          ?.writeAppLocale(locale?.languageCode);
    } catch (_) {
      // The choice still applies for this run; it just will not be remembered.
    }
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

/// The saved language as a [Locale], or null when none is saved or it is no longer supported.
Locale? localeFromCode(String? code) {
  for (final language in appLanguages) {
    if (language.locale.languageCode == code) return language.locale;
  }
  return null;
}

/// The texts in [locale] (the system's language when null), English when that language has none.
/// For code that has no [BuildContext], such as a provider that raises a toast.
AppLocalizations l10nFor(Locale? locale) {
  try {
    return lookupAppLocalizations(
      locale ?? WidgetsBinding.instance.platformDispatcher.locale,
    );
  } catch (_) {
    return lookupAppLocalizations(const Locale('en'));
  }
}
