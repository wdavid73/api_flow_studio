import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../shell/header_ghost_button.dart';
import '../theme/app_colors.dart';
import 'locale_provider.dart';

/// Header button, next to "Hosts & notes", that opens a menu to pick the language: one
/// entry per language of [appLanguages] and "System default" (the first one is checked
/// while no language was picked).
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  /// Menu value for "follow the system", since a null value would mean "dismissed".
  static const _system = Locale('system');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(localeProvider);
    final shown = selected ?? Localizations.localeOf(context);

    return PopupMenuButton<Locale>(
      key: const Key('language-button'),
      tooltip: l10n.languageTooltip,
      color: AppColors.surfaceContainerHigh,
      onSelected: (locale) => ref
          .read(localeProvider.notifier)
          .select(locale == _system ? null : locale),
      itemBuilder: (context) => [
        CheckedPopupMenuItem<Locale>(
          key: const Key('language-option-system'),
          value: _system,
          checked: selected == null,
          child: Text(l10n.languageSystemDefault),
        ),
        for (final language in appLanguages)
          CheckedPopupMenuItem<Locale>(
            key: Key('language-option-${language.locale.languageCode}'),
            value: language.locale,
            checked: selected?.languageCode == language.locale.languageCode,
            child: Text(language.name),
          ),
      ],
      // The button is the popup's own tap target; the ghost button is only its look.
      child: IgnorePointer(
        child: HeaderGhostButton(
          label: shown.languageCode.toUpperCase(),
          onPressed: () {},
        ),
      ),
    );
  }
}
