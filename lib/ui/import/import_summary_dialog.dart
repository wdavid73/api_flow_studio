import 'package:flutter/material.dart';

import '../../engine/import/import_result.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../../l10n/l10n.dart';
import 'import_summary_text.dart';

/// The most warnings the dialog lays out: a file can have thousands, and each is a widget.
const int maxListedImportWarnings = 200;

/// What an import did, and everything it had to leave out or change, listed.
Future<void> showImportSummaryDialog(BuildContext context, ImportSummary summary) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('import-summary-dialog'),
      title: Text(context.l10n.importSummaryTitle),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(describeImport(context.l10n, summary)),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.importWarningsHeader(summary.warnings.length),
              style: AppTypography.labelMd.copyWith(color: AppColors.warning),
            ),
            const SizedBox(height: AppSpacing.xs),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final (i, warning) in summary.warnings.take(maxListedImportWarnings).indexed)
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
                  if (summary.warnings.length > maxListedImportWarnings)
                    Padding(
                      key: const Key('import-warnings-hidden'),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Text(
                        context.l10n.importWarningsMore(summary.warnings.length - maxListedImportWarnings),
                        style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
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
          child: Text(context.l10n.commonClose),
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
      title: Text(context.l10n.importErrorTitle),
      content: Text(message),
      actions: [
        TextButton(
          key: const Key('import-error-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonClose),
        ),
      ],
    ),
  );
}
