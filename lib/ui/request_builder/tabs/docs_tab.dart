import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../request_draft_provider.dart';

/// Free-text description of what this endpoint does, for whoever opens it
/// later and needs context beyond the URL and method.
class DocsTab extends ConsumerWidget {
  const DocsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(requestDraftProvider);
    final notifier = ref.read(requestDraftProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextFormField(
        key: const Key('docs-description-field'),
        initialValue: draft.description,
        decoration: const InputDecoration(
          hintText: 'Describe para qué sirve este endpoint, cuándo usarlo, '
              'requisitos previos, etc.',
          alignLabelWithHint: true,
          border: OutlineInputBorder(),
        ),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        onChanged: notifier.setDescription,
      ),
    );
  }
}
