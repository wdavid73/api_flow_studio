import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../key_value_table.dart';
import '../request_draft_provider.dart';

class HeadersTab extends ConsumerWidget {
  const HeadersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(requestDraftProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: KeyValueTable(
        entries: draft.headers,
        onChanged: (value) => ref.read(requestDraftProvider.notifier).setHeaders(value),
      ),
    );
  }
}
