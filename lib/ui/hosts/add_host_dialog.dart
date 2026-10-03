import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../environments/environments_provider.dart';
import '../shell/header_ghost_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'host_matrix_provider.dart';

final RegExp _validName = RegExp(r'^\w+$');

/// Asks for the name of a new host. Pops with the name once it is valid, or
/// with null on Cancel. A valid name is non-empty, made of letters, digits and
/// underscores (so `{{name}}` can match it), not already a row, and not the
/// name of a secret variable.
class AddHostDialog extends ConsumerStatefulWidget {
  const AddHostDialog({super.key});

  @override
  ConsumerState<AddHostDialog> createState() => _AddHostDialogState();
}

class _AddHostDialogState extends ConsumerState<AddHostDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _validate(String name) {
    if (name.isEmpty) return 'Enter a name.';
    if (!_validName.hasMatch(name)) return 'Use letters, digits and underscores only.';

    final environments = ref.read(environmentsProvider).value?.environments ?? const [];
    final usedBySecret = environments.any((e) => e.variables[name]?.secret ?? false);
    if (usedBySecret) return 'A secret variable already uses that name.';

    if (ref.read(hostMatrixProvider).rows.any((r) => r.name == name)) return 'That host already exists.';
    return null;
  }

  void _submit() {
    final name = _controller.text.trim();
    final error = _validate(name);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add host'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('host-name-field'),
              controller: _controller,
              autofocus: true,
              style: AppTypography.codeMd,
              decoration: const InputDecoration(isDense: true, hintText: 'HOST_NAME'),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _error!,
                  key: const Key('host-name-error'),
                  style: AppTypography.bodySm.copyWith(color: AppColors.warning),
                ),
              ),
          ],
        ),
      ),
      actions: [
        HeaderGhostButton(
          key: const Key('host-name-cancel'),
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          key: const Key('host-name-confirm'),
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
