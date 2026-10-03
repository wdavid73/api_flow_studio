import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/hosts/host_matrix.dart';
import '../../engine/models/models.dart';
import '../environments/environments_provider.dart';
import '../shell/environment_kind.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'host_matrix_provider.dart';

const double _nameWidth = 240;
const double _environmentWidth = 230;

/// The table: a fixed first column with each base's name and usage, one column
/// per environment with that environment's value, scrolling sideways when
/// there are many environments.
class HostMatrixTable extends ConsumerWidget {
  const HostMatrixTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrix = ref.watch(hostMatrixProvider);
    final activeId = ref.watch(environmentsProvider).value?.activeEnvironmentId;

    if (matrix.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(
          key: const Key('hosts-empty'),
          child: Text(
            'No hosts yet — add an environment variable whose value is a URL, or use Add host.',
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      );
    }

    final width = _nameWidth + _environmentWidth * matrix.environments.length;

    return SingleChildScrollView(
      child: SingleChildScrollView(
        key: const Key('hosts-table-scroll'),
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderRow(environments: matrix.environments, activeId: activeId),
              for (final row in matrix.rows) _HostRowView(row: row, environments: matrix.environments),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.environments, required this.activeId});

  final List<Environment> environments;
  final String? activeId;

  @override
  Widget build(BuildContext context) {
    final kicker = AppTypography.kicker.copyWith(color: AppColors.outline);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outlineVariant))),
      child: Row(
        children: [
          SizedBox(width: _nameWidth, child: Text('HOST', style: kicker)),
          for (final environment in environments)
            SizedBox(
              key: Key('host-env-header-${environment.id}'),
              width: _environmentWidth,
              child: Row(
                children: [
                  if (environment.id == activeId) ...[
                    CircleAvatar(
                      key: Key('host-env-active-${environment.id}'),
                      radius: 4,
                      backgroundColor: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(child: Text(environment.name.toUpperCase(), style: kicker, overflow: TextOverflow.ellipsis)),
                  if (isProductionEnvironment(environment.name)) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      key: Key('host-env-prod-tag-${environment.id}'),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text('PROD', style: AppTypography.badgeMono.copyWith(color: AppColors.error)),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HostRowView extends StatelessWidget {
  const _HostRowView({required this.row, required this.environments});

  final HostRow row;
  final List<Environment> environments;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('host-row-${row.name}'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.outlineVariant))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _nameWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.name, style: AppTypography.codeMd.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  'Used by ${row.usedBy} ${row.usedBy == 1 ? 'request' : 'requests'}',
                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          for (final environment in environments)
            Container(
              key: Key('host-cell-${row.name}-${environment.id}'),
              width: _environmentWidth,
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: row.valueIn(environment.id) == null
                  ? Text('missing', style: AppTypography.bodySm.copyWith(color: AppColors.warning))
                  : Text(row.valueIn(environment.id)!, style: AppTypography.codeSm, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}
