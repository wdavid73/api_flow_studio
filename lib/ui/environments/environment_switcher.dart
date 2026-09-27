import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'environments_provider.dart';

/// Nav-bar dropdown to pick which environment is active. Switching here
/// changes what `{{variable}}` resolves to on the next Send, immediately
/// (SPEC criterion #2) -- no separate "apply" step. Styled as a pill (dot +
/// uppercase name + chevron) per design/*/code.html's header environment
/// indicator; the dropdown's own open-menu items keep a plainer row style.
class EnvironmentSwitcher extends ConsumerWidget {
  const EnvironmentSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(environmentsProvider).value;
    if (state == null || state.environments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: const Key('environment-switcher'),
          value: state.activeEnvironmentId,
          hint: const Text('No active environment'),
          icon: const Icon(Icons.expand_more, size: 16),
          selectedItemBuilder: (context) => [
            for (var i = 0; i < state.environments.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(radius: 4, backgroundColor: AppColors.environmentDotColor(i)),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    state.environments[i].name.toUpperCase(),
                    style: AppTypography.badgeMono.copyWith(color: AppColors.environmentDotColor(i)),
                  ),
                ],
              ),
          ],
          items: [
            for (var i = 0; i < state.environments.length; i++)
              DropdownMenuItem(
                value: state.environments[i].id,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: AppColors.environmentDotColor(i)),
                    const SizedBox(width: 8),
                    Text(state.environments[i].name),
                  ],
                ),
              ),
          ],
          onChanged: (id) => ref.read(environmentsProvider.notifier).setActive(id),
        ),
      ),
    );
  }
}
