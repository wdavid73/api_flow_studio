import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/collections_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'request_draft_provider.dart';
import '../../l10n/l10n.dart';

/// Heading above the URL bar: the endpoint's folder as a small uppercase
/// kicker (`UNSAVED` for a draft, `NO FOLDER` if its folder is gone), its
/// name as the title (click it to rename), and the first line of its
/// description.
class RequestHeader extends ConsumerStatefulWidget {
  const RequestHeader({super.key});

  @override
  ConsumerState<RequestHeader> createState() => _RequestHeaderState();
}

class _RequestHeaderState extends ConsumerState<RequestHeader> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    // Leaving the field (a click elsewhere) keeps what was typed, like Enter.
    _nameFocus.addListener(() {
      if (!_nameFocus.hasFocus && _editing) _commit();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _startEditing(String current) {
    _nameController.value = TextEditingValue(
      text: current,
      selection: TextSelection(baseOffset: 0, extentOffset: current.length),
    );
    setState(() => _editing = true);
    _nameFocus.requestFocus();
  }

  void _cancel() => setState(() => _editing = false);

  void _commit() {
    if (!_editing) return;
    final name = _nameController.text.trim();
    setState(() => _editing = false);
    final draft = ref.read(requestDraftProvider);
    if (name.isEmpty || name == draft.name) return;

    ref.read(requestDraftProvider.notifier).setName(name);
    // A saved request is renamed on disk right away (just the name: whatever
    // else is half-edited still waits for Save); a draft has nowhere to write.
    if (draft.id == draftEndpointId) return;
    final saved = ref.read(collectionsProvider).value?.endpoints.where((e) => e.id == draft.id).firstOrNull;
    if (saved != null) ref.read(collectionsProvider.notifier).updateEndpoint(saved.copyWith(name: name));
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(requestDraftProvider);
    final groups = ref.watch(collectionsProvider).value?.groups ?? const [];

    final String kicker;
    if (draft.id == draftEndpointId) {
      kicker = context.l10n.requestUnsaved;
    } else {
      final group = groups.where((g) => g.id == draft.groupId).firstOrNull;
      kicker = (group?.name ?? context.l10n.requestNoFolder).toUpperCase();
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
        if (_editing)
          CallbackShortcuts(
            bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
            child: TextField(
              key: const Key('request-header-title-field'),
              controller: _nameController,
              focusNode: _nameFocus,
              style: AppTypography.title,
              decoration: const InputDecoration(isDense: true),
              onSubmitted: (_) => _commit(),
            ),
          )
        else
          Tooltip(
            message: context.l10n.requestRenameTooltip,
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _startEditing(draft.name),
                child: Text(draft.name, key: const Key('request-header-title'), style: AppTypography.title),
              ),
            ),
          ),
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
