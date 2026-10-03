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
          InkWell(
            onTap: () => ref.read(sidebarMethodFilterProvider.notifier).state = method,
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: Container(
              key: Key('method-filter-$method'),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: method == selected ? AppColors.onSurface : null,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: method == selected ? AppColors.onSurface : AppColors.outlineVariant),
              ),
              child: Text(
                method == allMethods ? 'All' : method,
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.w700,
                  color: method == selected
                      ? AppColors.surface
                      : (method == allMethods ? AppColors.onSurfaceVariant : MethodBadge.colorForMethod(method)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
