import 'package:flutter/material.dart';

import '../../engine/flows/flow_step_result.dart';
import '../../engine/models/models.dart';
import '../response_viewer/response_body_tab.dart' show prettyResponseBody;
import '../shell/header_ghost_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/widgets/json_view.dart';
import '../theme/widgets/method_badge.dart';
import '../theme/widgets/pill_tab_bar.dart';
import '../theme/widgets/status_badge.dart';
import 'assertions_tab.dart';
import 'error_detail_panel.dart';
import '../../l10n/l10n.dart';

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
      if (failed) context.l10n.inspectorErrorDetails,
      if (result.assertionResults.isNotEmpty) context.l10n.assertionsTitle,
      context.l10n.inspectorRequestSent,
      context.l10n.inspectorResponseBody,
      context.l10n.commonHeaders,
    ];

    final response = result.response;
    final dot = Text('·', style: AppTypography.codeMd.copyWith(color: AppColors.outline));

    return Material(
      key: const Key('run-inspector-surface'),
      color: AppColors.responseBackground,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Padding(
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
                    endpoint?.name ?? context.l10n.runMissingEndpoint,
                    style: AppTypography.headlineSm,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (response?.status != null) ...[
                  StatusBadge(statusCode: response!.status!),
                  const SizedBox(width: AppSpacing.sm),
                  dot,
                  const SizedBox(width: AppSpacing.sm),
                  Text(context.l10n.commonTimeMs(response.elapsedMs), key: const Key('inspector-elapsed'), style: AppTypography.codeMd),
                  const SizedBox(width: AppSpacing.sm),
                  dot,
                  const SizedBox(width: AppSpacing.sm),
                  Text(context.l10n.commonSizeBytes(response.sizeBytes), key: const Key('inspector-size'), style: AppTypography.codeMd),
                ],
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
                    Align(alignment: Alignment.centerLeft, child: PillTabBar(labels: tabs)),
                    Expanded(
                      child: TabBarView(
                        children: [
                          if (failed) ErrorDetailPanel(result: result),
                          if (result.assertionResults.isNotEmpty) AssertionsTab(results: result.assertionResults),
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: SelectableText(
                              '${endpoint?.method ?? ''} ${requestUrl ?? context.l10n.inspectorNoRequest}',
                              style: const TextStyle(color: AppColors.onSurfaceVariant),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: result.response != null
                                ? SingleChildScrollView(
                                    child: Container(
                                      key: const Key('inspector-code-block'),
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(AppSpacing.md),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainerLowest,
                                        borderRadius: BorderRadius.circular(AppRadius.xl),
                                      ),
                                      child: JsonView(text: prettyResponseBody(result.response!.body)),
                                    ),
                                  )
                                : Text(
                                    context.l10n.inspectorNoResponse,
                                    style: TextStyle(color: AppColors.onSurfaceVariant),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: (result.response?.headers.isEmpty ?? true)
                                ? Text(
                                    context.l10n.commonNoHeaders,
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
              child: HeaderGhostButton(
                key: ValueKey('rerun-from-step-$index'),
                label: context.l10n.inspectorRerunFrom(index + 1),
                onPressed: onRerunFromHere ?? () {},
              ),
            ),
          ],
      ),
      ),
    );
  }
}
