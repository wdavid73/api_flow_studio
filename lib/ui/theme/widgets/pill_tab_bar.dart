import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

/// Tab bar where the selected tab is a filled rounded pill instead of an
/// underline (the playground's `.tabs` buttons). Must sit under a
/// [DefaultTabController] or be given a [controller].
class PillTabBar extends StatelessWidget {
  const PillTabBar({super.key, required this.labels, this.controller});

  final List<String> labels;
  final TabController? controller;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      labelColor: AppColors.onSurface,
      unselectedLabelColor: AppColors.onSurfaceVariant,
      labelStyle: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: AppTypography.bodyMd,
      labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      splashBorderRadius: BorderRadius.circular(AppRadius.xl),
      tabs: [for (final label in labels) Tab(text: label, height: 32)],
    );
  }
}
