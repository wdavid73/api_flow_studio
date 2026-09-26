import 'package:flutter/material.dart';

import '../../engine/flows/flow_step_result.dart';
import '../../engine/models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/widgets/method_badge.dart';
import '../theme/widgets/status_badge.dart';

/// One step in the flow run view's execution timeline. [result] is null
/// while the step hasn't executed yet (still queued behind earlier steps).
class RunStepCard extends StatelessWidget {
  const RunStepCard({
    super.key,
    required this.index,
    required this.endpoint,
    required this.result,
  });

  final int index;
  final Endpoint? endpoint;
  final FlowStepResult? result;

  @override
  Widget build(BuildContext context) {
    final status = result?.status;
    final IconData icon;
    final Color iconColor;
    switch (status) {
      case FlowStepStatus.success:
        icon = Icons.check_circle;
        iconColor = AppColors.tertiary;
      case FlowStepStatus.failure:
        icon = Icons.cancel;
        iconColor = AppColors.error;
      case FlowStepStatus.skipped:
        icon = Icons.do_not_disturb_on;
        iconColor = AppColors.outline;
      case null:
        icon = Icons.radio_button_unchecked;
        iconColor = AppColors.outline;
    }

    return Opacity(
      opacity: status == FlowStepStatus.skipped ? 0.5 : 1,
      child: Card(
        key: ValueKey('run-step-card-$index'),
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: iconColor, key: ValueKey('run-step-status-icon-$index')),
              const SizedBox(width: AppSpacing.sm),
              if (endpoint != null) MethodBadge(method: endpoint!.method),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      endpoint?.name ?? 'Missing endpoint',
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result?.failureReason != null)
                      Text(
                        result!.failureReason!,
                        style: TextStyle(color: AppColors.error),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (status == FlowStepStatus.skipped)
                      Text(
                        'Skipped',
                        style: TextStyle(color: AppColors.outline),
                      ),
                  ],
                ),
              ),
              if (result?.response?.status != null)
                StatusBadge(statusCode: result!.response!.status!),
            ],
          ),
        ),
      ),
    );
  }
}
