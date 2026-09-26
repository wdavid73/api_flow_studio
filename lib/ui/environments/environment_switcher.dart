import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import 'environments_provider.dart';

/// Nav-bar dropdown to pick which environment is active. Switching here
/// changes what `{{variable}}` resolves to on the next Send, immediately
/// (SPEC criterion #2) -- no separate "apply" step.
class EnvironmentSwitcher extends ConsumerWidget {
  const EnvironmentSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(environmentsProvider).value;
    if (state == null || state.environments.isEmpty) {
      return const SizedBox.shrink();
    }

    return DropdownButton<String>(
      key: const Key('environment-switcher'),
      value: state.activeEnvironmentId,
      hint: const Text('No active environment'),
      underline: const SizedBox.shrink(),
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
    );
  }
}
