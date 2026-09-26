import 'package:flutter/material.dart';

import '../../engine/flows/flow_step_result.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A failed step's diagnostics: a short human-readable classification of
/// [FlowStepResult.failureReason] plus the raw reason text.
class ErrorDetailPanel extends StatelessWidget {
  const ErrorDetailPanel({super.key, required this.result});

  final FlowStepResult result;

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
          if (result.failureReason != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                result.failureReason!,
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
