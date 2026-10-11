import 'package:flutter/material.dart';

import '../../engine/flows/flow_step_result.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A failed step's diagnostics: a short human-readable classification of
/// [FlowStepResult.failureReason] plus the raw reason text.
class ErrorDetailPanel extends StatelessWidget {
  const ErrorDetailPanel({super.key, required this.result});

  final FlowStepResult result;

  List<String> get _lines {
    final failed = [
      for (final r in result.assertionResults)
        if (!r.passed && r.message != null) r.message!,
    ];
    if (failed.isNotEmpty) return failed;
    final reason = result.failureReason;
    return reason == null ? const [] : [reason];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            classifyFailure(result),
            style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
          ),
          // One line per failed assertion (a step can fail several). They come from
          // the structured results, not from splitting the reason text: the value
          // an assertion saw may itself contain line breaks.
          for (final (i, line) in _lines.indexed)
            Padding(
              key: ValueKey('error-line-$i'),
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                line,
                style: const TextStyle(color: AppColors.onSurface),
              ),
            ),
        ],
      ),
    );
  }
}

/// A short, human-readable label for [result]'s failure, derived from the
/// shape of [FlowRunner]'s three failure-reason messages -- there's no
/// separate error-code field to classify on.
String classifyFailure(FlowStepResult result) {
  final reason = result.failureReason;
  if (reason == null) return 'Unknown Error';
  if (reason.startsWith('Assertion failed')) return 'Assertion Failure';
  if (reason.startsWith('Endpoint ') && reason.endsWith('not found')) return 'Configuration Error';
  return 'Network Error';
}
