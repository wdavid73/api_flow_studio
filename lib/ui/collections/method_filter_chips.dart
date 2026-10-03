import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/widgets/method_badge.dart';
import 'endpoint_filter.dart';

/// The method the sidebar is filtered to ([allMethods] for none). UI-only
/// state, not persisted.
final sidebarMethodFilterProvider = StateProvider<String>((ref) => allMethods);

const _chips = [allMethods, 'GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

/// A 3-column grid of method chips (`All`, GET, POST, ...). Exactly one is
/// active; the active one is filled with the on-surface color.
class MethodFilterChips extends ConsumerWidget {
  const MethodFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(sidebarMethodFilterProvider);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: AppSpacing.xs,
      crossAxisSpacing: AppSpacing.xs,
      childAspectRatio: 4,
      children: [
        for (final method in _chips)
          MethodChip(
            containerKey: Key('method-filter-$method'),
            label: method == allMethods ? 'All' : method,
            color: method == allMethods ? AppColors.onSurfaceVariant : MethodBadge.colorForMethod(method),
            selected: method == selected,
            onTap: () => ref.read(sidebarMethodFilterProvider.notifier).state = method,
          ),
      ],
    );
  }
}

/// A pill chip for a method filter: outlined with the verb [color] when idle,
/// filled with the on-surface color when [selected]. Shared by the sidebar and
/// the add-step picker so both read as the same control. Fills its parent when
/// the parent gives it tight constraints (a grid cell) and otherwise sizes to
/// its label.
class MethodChip extends StatelessWidget {
  const MethodChip({
    super.key,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.containerKey,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  /// Key for the chip's visual container (what tests inspect).
  final Key? containerKey;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        key: containerKey,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? AppColors.onSurface : null,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: selected ? AppColors.onSurface : AppColors.outlineVariant),
        ),
        child: Text(
          label,
          style: AppTypography.labelMd.copyWith(
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.surface : color,
          ),
        ),
      ),
    );
  }
}
