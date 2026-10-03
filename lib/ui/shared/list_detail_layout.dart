import 'package:flutter/material.dart';

import '../shell/header_ghost_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Width of the list panel in list/detail screens (matches the workspace
/// sidebar).
const double listPanelWidth = 300;

/// A 300px list panel (header on top, then the list) with an `outlineVariant`
/// right border, next to a detail area that fills the remaining width. Used by
/// Environments and Flows.
class ListDetailLayout extends StatelessWidget {
  const ListDetailLayout({
    super.key,
    required this.header,
    required this.list,
    required this.detail,
  });

  final Widget header;
  final Widget list;
  final Widget detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('list-detail-list-panel'),
          width: listPanelWidth,
          decoration: const BoxDecoration(
            border: Border(right: BorderSide(color: AppColors.outlineVariant)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Expanded(child: list),
            ],
          ),
        ),
        Expanded(key: const Key('list-detail-detail-panel'), child: detail),
      ],
    );
  }
}

/// Top of a list panel: a `kicker` [title] and a ghost [actionLabel] button
/// (e.g. `New Environment`).
class ListPanelHeader extends StatelessWidget {
  const ListPanelHeader({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.actionKey,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final Key actionKey;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.kicker.copyWith(color: AppColors.outline))),
          HeaderGhostButton(key: actionKey, label: actionLabel, onPressed: onAction),
        ],
      ),
    );
  }
}
