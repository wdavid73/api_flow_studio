import 'package:flutter/material.dart';

import '../../engine/flows/flow_step_result.dart';
import '../../engine/models/models.dart';
import '../response_viewer/response_body_tab.dart' show prettyResponseBody;
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/widgets/json_view.dart';
import '../theme/widgets/method_badge.dart';
import '../theme/widgets/status_badge.dart';
import 'error_detail_panel.dart';

/// One step in the flow run view's execution timeline. [result] is null
/// while the step hasn't executed yet (still queued behind earlier steps).
/// A completed (non-skipped) step can be expanded to show its interpolated
/// request, response, and -- if it failed -- an [ErrorDetailPanel]; from
/// there it can also be re-run on its own via [onRerunFromHere].
class RunStepCard extends StatelessWidget {
  const RunStepCard({
    super.key,
    required this.index,
    required this.endpoint,
    required this.result,
    this.requestUrl,
    this.expanded = false,
    this.onToggleExpanded,
    this.onRerunFromHere,
  });

  final int index;
  final Endpoint? endpoint;
  final FlowStepResult? result;
  final String? requestUrl;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final VoidCallback? onRerunFromHere;

  bool get _isExpandable => result != null && result!.status != FlowStepStatus.skipped;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                key: ValueKey('run-step-header-$index'),
                onTap: _isExpandable ? onToggleExpanded : null,
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
                              style: const TextStyle(color: AppColors.error),
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (status == FlowStepStatus.skipped)
                            const Text(
                              'Skipped',
                              style: TextStyle(color: AppColors.outline),
                            ),
                        ],
                      ),
                    ),
                    if (result?.response?.status != null)
                      StatusBadge(statusCode: result!.response!.status!),
                    if (_isExpandable)
                      Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                  ],
                ),
              ),
              if (expanded && _isExpandable) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Request',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      SelectableText(
                        '${endpoint?.method ?? ''} ${requestUrl ?? ''}',
                        style: const TextStyle(color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (result!.status == FlowStepStatus.failure) ...[
                        ErrorDetailPanel(result: result!),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (result!.response != null) ...[
                        Text(
                          'Response',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        JsonView(text: prettyResponseBody(result!.response!.body)),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: ValueKey('rerun-from-step-$index'),
                          onPressed: onRerunFromHere,
                          child: Text('Re-run From Step ${index + 1}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
