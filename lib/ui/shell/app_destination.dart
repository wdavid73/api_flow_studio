import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';

enum AppDestination {
  workspace,
  environments,
  flows,
  history;

  /// The name shown in the header's navigation, in the current language.
  String label(AppLocalizations l10n) => switch (this) {
        workspace => l10n.navWorkspace,
        environments => l10n.navEnvironments,
        flows => l10n.navFlows,
        history => l10n.navHistory,
      };
}

final selectedDestinationProvider = StateProvider<AppDestination>(
  (ref) => AppDestination.workspace,
);
