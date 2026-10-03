import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shell/header_ghost_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'add_host_dialog.dart';
import 'host_matrix_provider.dart';
import 'host_matrix_table.dart';

/// The "Hosts & notes" dialog: help text and the hosts-by-environment table.
class HostsDialog extends ConsumerWidget {
  const HostsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      backgroundColor: AppColors.surfaceContainerLow,
      insetPadding: const EdgeInsets.all(AppSpacing.xl - 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.dialog),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: ConstrainedBox(
        key: const Key('hosts-dialog'),
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl - 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Hosts by environment', style: AppTypography.headlineMd)),
                  HeaderGhostButton(
                    key: const Key('hosts-add-button'),
                    label: 'Add host',
                    onPressed: () async {
                      final name = await showDialog<String>(context: context, builder: (_) => const AddHostDialog());
                      if (name != null) {
                        ref.read(pinnedHostsProvider.notifier).update((pinned) => {...pinned, name});
                      }
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  HeaderGhostButton(
                    key: const Key('hosts-close-button'),
                    label: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Hosts are environment variables whose value is a URL. Edit a cell to change it in that '
                'environment; clear it to remove the variable there.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Flexible(child: HostMatrixTable()),
            ],
          ),
        ),
      ),
    );
  }
}
