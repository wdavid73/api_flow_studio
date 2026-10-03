import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_typography.dart';
import '../theme/widgets/method_badge.dart';
import 'request_draft_provider.dart';

const _methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

/// HTTP method dropdown for the URL bar: the current verb in mono text
/// colored like its [MethodBadge], with the same coloring in the menu.
class MethodSelector extends ConsumerWidget {
  const MethodSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final method = ref.watch(requestDraftProvider.select((d) => d.method));

    TextStyle styleFor(String m) =>
        AppTypography.codeLg.copyWith(color: MethodBadge.colorForMethod(m), fontWeight: FontWeight.w600);

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: const Key('method-selector'),
        value: method,
        items: [
          for (final m in _methods) DropdownMenuItem(value: m, child: Text(m, style: styleFor(m))),
        ],
        selectedItemBuilder: (context) => [
          for (final m in _methods) Align(alignment: Alignment.centerLeft, child: Text(m, style: styleFor(m))),
        ],
        onChanged: (value) {
          if (value != null) ref.read(requestDraftProvider.notifier).setMethod(value);
        },
      ),
    );
  }
}
