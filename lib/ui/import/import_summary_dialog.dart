import 'package:flutter/material.dart';

import '../../engine/import/import_result.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// What an import did, and everything it had to leave out or change, listed.
Future<void> showImportSummaryDialog(BuildContext context, ImportSummary summary) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('import-summary-dialog'),
      title: const Text('Import summary'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary.describe()),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${summary.warnings.length} ${summary.warnings.length == 1 ? 'thing was' : 'things were'} left out or changed:',
              style: AppTypography.labelMd.copyWith(color: AppColors.warning),
            ),
            const SizedBox(height: AppSpacing.xs),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final (i, warning) in summary.warnings.indexed)
                    Padding(
                      key: ValueKey('import-warning-$i'),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (warning.where.isNotEmpty) SelectableText(warning.where, style: AppTypography.codeSm),
                          SelectableText(warning.message, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('import-summary-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// A file that could not be imported, and why.
Future<void> showImportErrorDialog(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('import-error-dialog'),
      title: const Text('Could not import'),
      content: Text(message),
      actions: [
        TextButton(
          key: const Key('import-error-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
