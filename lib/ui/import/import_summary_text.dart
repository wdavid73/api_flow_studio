import '../../engine/import/import_result.dart';
import '../../l10n/app_localizations.dart';

/// One line saying what an import did, in the current language: `Imported Postman collection:
/// 12 requests in 4 folders, 1 environment — 2 values to fill in`. The warnings are listed apart.
String describeImport(AppLocalizations l10n, ImportSummary summary) {
  final parts = [
    if (summary.requests > 0 || summary.folders > 0) l10n.importPartsRequestsInFolders(summary.requests, summary.folders),
    if (summary.environments > 0) l10n.importPartsEnvironments(summary.environments),
  ];
  final fill = summary.valuesToFill > 0 ? l10n.importValuesToFill(summary.valuesToFill) : '';
  return l10n.importDescribe(summary.source, parts.isEmpty ? l10n.importPartsNothing : parts.join(', '), fill);
}
