import 'package:flutter/material.dart';

import '../../engine/models/models.dart';
import '../theme/app_spacing.dart';

/// Editable key/value/enabled table shared by the Params and Headers tabs
/// (and, from Task 2.4 onward, the formUrlEncoded body editor).
class KeyValueTable extends StatelessWidget {
  const KeyValueTable({super.key, required this.entries, required this.onChanged});

  final List<KeyValueEntry> entries;
  final ValueChanged<List<KeyValueEntry>> onChanged;

  void _updateAt(int index, KeyValueEntry Function(KeyValueEntry) update) {
    final next = [...entries];
    next[index] = update(next[index]);
    onChanged(next);
  }

  void _removeAt(int index) {
    final next = [...entries]..removeAt(index);
    onChanged(next);
  }

  void _addRow() => onChanged([...entries, const KeyValueEntry(key: '', value: '')]);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++)
          _KeyValueRow(
            key: ValueKey('kv-row-$i'),
            entry: entries[i],
            onToggle: (enabled) => _updateAt(i, (e) => e.copyWith(enabled: enabled)),
            onKeyChanged: (key) => _updateAt(i, (e) => e.copyWith(key: key)),
            onValueChanged: (value) => _updateAt(i, (e) => e.copyWith(value: value)),
            onDelete: () => _removeAt(i),
          ),
        TextButton.icon(
          onPressed: _addRow,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add row'),
        ),
      ],
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    super.key,
    required this.entry,
    required this.onToggle,
    required this.onKeyChanged,
    required this.onValueChanged,
    required this.onDelete,
  });

  final KeyValueEntry entry;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onKeyChanged;
  final ValueChanged<String> onValueChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Checkbox(
            key: const Key('kv-enabled-checkbox'),
            value: entry.enabled,
            onChanged: (v) => onToggle(v ?? true),
          ),
          Expanded(
            child: TextFormField(
              key: const Key('kv-key-field'),
              initialValue: entry.key,
              decoration: const InputDecoration(hintText: 'Key', isDense: true),
              onChanged: onKeyChanged,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextFormField(
              key: const Key('kv-value-field'),
              initialValue: entry.value,
              decoration: const InputDecoration(hintText: 'Value', isDense: true),
              onChanged: onValueChanged,
            ),
          ),
          IconButton(
            key: const Key('kv-delete-button'),
            icon: const Icon(Icons.close, size: 16),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
