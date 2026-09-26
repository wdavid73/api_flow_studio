import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/models/models.dart';
import '../../theme/widgets/json_editor.dart';
import '../key_value_table.dart';
import '../request_draft_provider.dart';

enum BodyKind { none, json, formUrlEncoded }

class BodyTab extends ConsumerWidget {
  const BodyTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(requestDraftProvider);
    final notifier = ref.read(requestDraftProvider.notifier);
    final kind = draft.body.map(
      none: (_) => BodyKind.none,
      json: (_) => BodyKind.json,
      formUrlEncoded: (_) => BodyKind.formUrlEncoded,
    );

    void setKind(BodyKind newKind) {
      switch (newKind) {
        case BodyKind.none:
          notifier.setBody(const RequestBody.none());
        case BodyKind.json:
          notifier.setBody(const RequestBody.json(''));
        case BodyKind.formUrlEncoded:
          notifier.setBody(const RequestBody.formUrlEncoded([]));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<BodyKind>(
            key: const Key('body-kind-selector'),
            segments: const [
              ButtonSegment(value: BodyKind.none, label: Text('None')),
              ButtonSegment(value: BodyKind.json, label: Text('JSON')),
              ButtonSegment(value: BodyKind.formUrlEncoded, label: Text('Form URL-Encoded')),
            ],
            selected: {kind},
            onSelectionChanged: (selection) => setKind(selection.first),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: draft.body.map(
              none: (_) => const Center(child: Text('This request has no body')),
              json: (b) => SingleChildScrollView(
                child: JsonEditorField(
                  text: b.raw,
                  onChanged: (value) => notifier.setBody(RequestBody.json(value)),
                ),
              ),
              formUrlEncoded: (b) => SingleChildScrollView(
                child: KeyValueTable(
                  entries: b.fields,
                  onChanged: (fields) => notifier.setBody(RequestBody.formUrlEncoded(fields)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
