import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  /// The texts in the current language. Outside an app that has the localization delegates
  /// (a bare `MaterialApp` in a test, for example) it falls back to English instead of failing.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ?? lookupAppLocalizations(const Locale('en'));
}
