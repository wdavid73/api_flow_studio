import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../environments/environments_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'environment_kind.dart';

/// Segmented environment selector for the header: one button per
/// environment, the active one filled with the accent (red when it's a production
/// environment). Picking a button changes what `{{variable}}` resolves to on
/// the next Send, immediately. With more than [_maxButtons] environments
/// the first [_maxButtons] - 1 stay as buttons and the rest move into a
/// `...` menu, which itself lights up when one of them is active.
class EnvironmentPill extends ConsumerWidget {
  const EnvironmentPill({super.key});

  static const int _maxButtons = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(environmentsProvider).value;
    if (state == null || state.environments.isEmpty) return const SizedBox.shrink();

    final all = state.environments;
    final hasOverflow = all.length > _maxButtons;
    final shown = hasOverflow ? all.take(_maxButtons - 1).toList() : all;
    final overflow = hasOverflow ? all.skip(_maxButtons - 1).toList() : const <Environment>[];
    final activeId = state.activeEnvironmentId;
    final activeInOverflow = overflow.any((e) => e.id == activeId);
    final activeIsProd = state.active != null && isProductionEnvironment(state.active!.name);

    void select(String id) => ref.read(environmentsProvider.notifier).setActive(id);

    return Container(
      key: const Key('environment-switcher'),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final env in shown)
            _Segment(
              segmentKey: Key('env-pill-${env.id}'),
              active: env.id == activeId,
              production: isProductionEnvironment(env.name),
              onTap: () => select(env.id),
              child: Text(env.name),
            ),
          if (hasOverflow)
            PopupMenuButton<String>(
              key: const Key('environment-overflow'),
              tooltip: 'More environments',
              padding: EdgeInsets.zero,
              onSelected: select,
              itemBuilder: (context) => [
                for (final env in overflow)
                  PopupMenuItem(
                    value: env.id,
                    child: Text(env.name),
                  ),
              ],
              child: _SegmentBody(
                segmentKey: const Key('env-pill-overflow'),
                active: activeInOverflow,
                production: activeInOverflow && activeIsProd,
                child: const Text('…'),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.segmentKey,
    required this.active,
    required this.production,
    required this.onTap,
    required this.child,
  });

  final Key segmentKey;
  final bool active;
  final bool production;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: _SegmentBody(segmentKey: segmentKey, active: active, production: production, child: child),
    );
  }
}

class _SegmentBody extends StatelessWidget {
  const _SegmentBody({
    required this.segmentKey,
    required this.active,
    required this.production,
    required this.child,
  });

  final Key segmentKey;
  final bool active;
  final bool production;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fill = !active ? null : (production ? AppColors.error : AppColors.primary);
    final textColor = !active
        ? AppColors.onSurfaceVariant
        : (production ? AppColors.onError : AppColors.onPrimary);

    return Container(
      key: segmentKey,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg - 2, vertical: AppSpacing.sm),
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(AppRadius.full)),
      child: DefaultTextStyle(
        style: AppTypography.bodyMd.copyWith(color: textColor, fontWeight: FontWeight.w600),
        child: child,
      ),
    );
  }
}
