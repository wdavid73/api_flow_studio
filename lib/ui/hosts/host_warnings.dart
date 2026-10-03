import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/hosts/host_matrix.dart';
import '../environments/environments_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'host_matrix_provider.dart';

/// Under the table: one warning per base missing in some environment (those
/// that would break a Send in the active environment first), or a line saying
/// everything is defined. Shows nothing when there are no bases at all.
class HostWarnings extends ConsumerWidget {
  const HostWarnings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrix = ref.watch(hostMatrixProvider);
    if (matrix.rows.isEmpty) return const SizedBox.shrink();

    final activeId = ref.watch(environmentsProvider).value?.activeEnvironmentId;
    final warnings = hostWarnings(matrix, activeEnvironmentId: activeId);

    if (warnings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.lg),
        child: Text(
          'Every host is defined in every environment.',
          key: const Key('hosts-all-defined'),
          style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final warning in warnings) _WarningCard(warning: warning)],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.warning});

  final HostWarning warning;

  @override
  Widget build(BuildContext context) {
    final body = AppTypography.bodyMd.copyWith(color: AppColors.warning);

    return Container(
      key: Key('host-warning-${warning.name}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg - 2, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bannerBackground,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          if (warning.affectsActiveEnvironment) ...[
            Container(
              key: const Key('host-warning-active-tag'),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text('ACTIVE', style: AppTypography.badgeMono.copyWith(color: AppColors.warning)),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Text.rich(
              TextSpan(
                style: body,
                children: [
                  TextSpan(text: warning.name, style: AppTypography.codeMd.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700)),
                  TextSpan(text: " isn't defined in ${warning.missingEnvironmentNames.join(', ')}. Requests that use "),
                  TextSpan(text: '{{${warning.name}}}', style: AppTypography.codeMd.copyWith(color: AppColors.warning)),
                  const TextSpan(text: ' will be sent with that text unresolved there.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
