import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../environments/environments_provider.dart';
import '../theme/app_colors.dart';
import 'environment_kind.dart';

/// 3px red bar pinned to the top edge of the window while a production
/// environment is active, so it's obvious a Send will hit real data. With
/// any other environment (or none) it collapses to zero height; the widget
/// stays mounted so it keeps a stable key.
class ProductionStrip extends ConsumerWidget {
  const ProductionStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(environmentsProvider).value?.active;
    final isProd = active != null && isProductionEnvironment(active.name);

    return Container(
      key: const Key('active-environment-strip'),
      height: isProd ? 3 : 0,
      color: AppColors.error,
    );
  }
}
