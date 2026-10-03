import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/collections_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'request_draft_provider.dart';

/// Heading above the URL bar: the endpoint's folder as a small uppercase
/// kicker (`UNSAVED` for a draft, `NO FOLDER` if its folder is gone), its
/// name as the title, and the first line of its description.
class RequestHeader extends ConsumerWidget {
  const RequestHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(requestDraftProvider);
    final groups = ref.watch(collectionsProvider).value?.groups ?? const [];

    final String kicker;
    if (draft.id == draftEndpointId) {
      kicker = 'UNSAVED';
    } else {
      final group = groups.where((g) => g.id == draft.groupId).firstOrNull;
      kicker = (group?.name ?? 'NO FOLDER').toUpperCase();
    }
    final description = draft.description.trim().split('\n').first.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kicker,
          key: const Key('request-header-kicker'),
          style: AppTypography.kicker.copyWith(color: AppColors.outline),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(draft.name, key: const Key('request-header-title'), style: AppTypography.title),
        if (description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            key: const Key('request-header-description'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}
