import 'package:flutter/material.dart';

import '../../engine/flows/flow_step_result.dart';
import '../../engine/models/models.dart';
import '../response_viewer/response_body_tab.dart' show prettyResponseBody;
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/widgets/json_view.dart';
import '../theme/widgets/method_badge.dart';
import '../theme/widgets/status_badge.dart';
import 'error_detail_panel.dart';

/// The right-hand detail panel for whichever step is selected in the run
/// view's timeline: a tabbed inspector (Error Details -- only for a failed
/// step -- / Request Sent / Response Body / Headers), matching
/// design/flow_run_view/code.html's 2-panel layout. [result] is always a
/// completed, non-skipped step's result -- the screen only lets a
/// selectable ([RunStepCard._isSelectable]) step become the selection.
class RunStepInspector extends StatelessWidget {
  const RunStepInspector({
    super.key,
    required this.index,
    required this.endpoint,
    required this.result,
    required this.requestUrl,
    required this.onRerunFromHere,
  });

  final int index;
  final Endpoint? endpoint;
  final FlowStepResult result;
  final String? requestUrl;
  final VoidCallback? onRerunFromHere;

  @override
  Widget build(BuildContext context) {
    final failed = result.status == FlowStepStatus.failure;
    final tabs = [
      if (failed) 'Error Details',
      'Request Sent',
      'Response Body',
      'Headers',
    ];

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (endpoint != null) MethodBadge(method: endpoint!.method),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  endpoint?.name ?? 'Missing endpoint',
                  style: AppTypography.headlineSm,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (result.response?.status != null) StatusBadge(statusCode: result.response!.status!),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: DefaultTabController(
              key: ValueKey('inspector-tabs-$index'),
              length: tabs.length,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [for (final t in tabs) Tab(text: t)],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        if (failed) ErrorDetailPanel(result: result),
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: SelectableText(
                            '${endpoint?.method ?? ''} ${requestUrl ?? 'No request was sent'}',
                            style: const TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: result.response != null
                              ? SingleChildScrollView(
                                  child: JsonView(text: prettyResponseBody(result.response!.body)),
                                )
                              : const Text(
                                  'No response received',
                                  style: TextStyle(color: AppColors.onSurfaceVariant),
                                ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: (result.response?.headers.isEmpty ?? true)
                              ? const Text(
                                  'No headers',
                                  style: TextStyle(color: AppColors.onSurfaceVariant),
                                )
                              : ListView(
                                  children: [
                                    for (final entry in result.response!.headers.entries)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: AppSpacing.xs,
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: 200,
                                              child: Text(
                                                entry.key,
                                                style: AppTypography.codeSm.copyWith(
                                                  color: AppColors.secondary,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: SelectableText(
                                                entry.value,
                                                style: AppTypography.codeSm,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
    );
  }
}
