import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import 'environments_provider.dart';

/// The 3px environment-health strip pinned to the very top of the window
/// (DESIGN.md "Top Layer"), colored to match the active environment so
/// it's obvious which one is live without opening a menu.
class ActiveEnvironmentStrip extends ConsumerWidget {
  const ActiveEnvironmentStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(environmentsProvider).value;
    final index = state == null
        ? -1
        : state.environments.indexWhere((e) => e.id == state.activeEnvironmentId);

    return Container(
      key: const Key('active-environment-strip'),
      height: 3,
      color: index >= 0 ? AppColors.environmentDotColor(index) : AppColors.outlineVariant,
    );
  }
}
