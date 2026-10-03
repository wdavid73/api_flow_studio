import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/widgets/app_logo.dart';
import '../projects/project_switcher.dart';
import 'app_destination.dart';
import 'environment_pill.dart';

/// Window width below which the header wraps onto several lines instead of
/// staying a single 56px row.
const double _wrapBreakpoint = 1100;

/// Top bar: brand, the project switcher, destination navigation, the environment pill and a
/// right-hand zone for [actions] (other modules add their buttons there).
class AppHeader extends ConsumerWidget {
  const AppHeader({super.key, this.actions = const []});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDestinationProvider);

    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppLogoMark(size: 28),
        const SizedBox(width: AppSpacing.md),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('API Flow Studio', style: AppTypography.headlineSm.copyWith(letterSpacing: -0.42)),
            Text('API playground', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ),
      ],
    );

    // A Wrap, not a Row: with the project switcher in the header the navigation
    // may get less room than it needs and has to break onto another line.
    final nav = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final destination in AppDestination.values)
          _NavItem(
            destination: destination,
            isSelected: destination == selected,
            onTap: () => ref.read(selectedDestinationProvider.notifier).state = destination,
          ),
      ],
    );

    final actionRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final action in actions)
          Padding(padding: const EdgeInsets.only(left: AppSpacing.sm), child: action),
      ],
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        border: const Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin + 4, vertical: AppSpacing.md - 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _wrapBreakpoint) {
            // The middle group wraps onto a second line only when it does not
            // fit (many environments plus several action buttons).
            return Row(
              children: [
                brand,
                const SizedBox(width: AppSpacing.lg),
                const ProjectSwitcher(),
                const SizedBox(width: AppSpacing.xl),
                Expanded(
                  child: Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [nav, const EnvironmentPill()],
                  ),
                ),
                actionRow,
              ],
            );
          }
          return Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [brand, const ProjectSwitcher(), nav, const EnvironmentPill(), actionRow],
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.destination, required this.isSelected, required this.onTap});

  final AppDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.field - 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceContainerHigh : null,
            borderRadius: BorderRadius.circular(AppRadius.field - 2),
          ),
          child: Text(
            destination.label,
            style: AppTypography.bodyMd.copyWith(
              color: isSelected ? AppColors.onSurface : AppColors.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
