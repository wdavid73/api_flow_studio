import 'package:flutter/material.dart';

import '../../engine/flows/flow_step_result.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// What a step checked: one row per assertion with a pass/fail mark, the check
/// in words and, when it failed, why.
class AssertionsTab extends StatelessWidget {
  const AssertionsTab({super.key, required this.results});

  final List<AssertionResult> results;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      children: [
        for (var i = 0; i < results.length; i++)
          Padding(
            key: ValueKey('assertion-result-$i'),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  results[i].passed ? Icons.check_circle : Icons.cancel,
                  key: ValueKey(results[i].passed ? 'assertion-passed-$i' : 'assertion-failed-$i'),
                  size: 16,
                  color: results[i].passed ? AppColors.tertiary : AppColors.error,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(results[i].assertion.describe(), style: AppTypography.codeMd),
                      if (!results[i].passed && results[i].message != null)
                        SelectableText(
                          results[i].message!,
                          style: AppTypography.codeSm.copyWith(color: AppColors.error),
                        ),
                      if (results[i].passed && results[i].actual != null)
                        SelectableText(
                          'got "${results[i].actual}"',
                          style: AppTypography.codeSm.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
