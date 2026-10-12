import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'file_picker_service.dart';
import '../../l10n/l10n.dart';

/// The Form Data body editor: one row per field (enabled, name, Text/File, then a
/// text value or a path with a Choose button and a content type, remove) and an
/// "Add field" button.
///
/// The text fields only read their `initialValue` once, so each row has an id of
/// its own and gets a new one whenever its text changes from outside the field (a
/// file picked, the kind switched, another body arriving): removing a row or
/// swapping the body rebuilds the fields instead of leaving the old text in them.
class MultipartTable extends ConsumerStatefulWidget {
  const MultipartTable({super.key, required this.fields, required this.onChanged});

  final List<MultipartField> fields;
  final ValueChanged<List<MultipartField>> onChanged;

  @override
  ConsumerState<MultipartTable> createState() => _MultipartTableState();
}

class _MultipartTableState extends ConsumerState<MultipartTable> {
  var _nextId = 0;
  late List<int> _ids = _freshIds(widget.fields.length);

  /// The list this table last handed to [MultipartTable.onChanged], to tell its own
  /// edits apart from a different body arriving in the same place.
  List<MultipartField>? _emitted;

  List<int> _freshIds(int count) => [for (var i = 0; i < count; i++) _nextId++];

  @override
  void didUpdateWidget(MultipartTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final mine = listEquals(widget.fields, _emitted);
    if (widget.fields.length != _ids.length || (!mine && !listEquals(widget.fields, oldWidget.fields))) {
      _ids = _freshIds(widget.fields.length);
    }
  }

  void _emit(List<MultipartField> next) {
    _emitted = next;
    widget.onChanged(next);
  }

  /// A change typed into a field: the field already shows it, so keep the row.
  void _edit(int row, MultipartField field) {
    final next = [...widget.fields];
    next[row] = field;
    _emit(next);
  }

  /// A change the field does not know about: show it by rebuilding the row.
  void _replace(int row, MultipartField field) {
    setState(() => _ids = [..._ids]..[row] = _nextId++);
    _edit(row, field);
  }

  void _remove(int row) {
    setState(() => _ids = [..._ids]..removeAt(row));
    _emit([...widget.fields]..removeAt(row));
  }

  void _add() {
    setState(() => _ids = [..._ids, _nextId++]);
    _emit([...widget.fields, const MultipartField(name: '')]);
  }

  Future<void> _choose(int row) async {
    final path = await ref.read(filePickerServiceProvider).pickFile();
    if (path == null || !mounted || row >= widget.fields.length) return;
    _replace(row, widget.fields[row].copyWith(value: path));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var row = 0; row < widget.fields.length; row++)
          KeyedSubtree(
            key: ValueKey('multipart-row-${_ids[row]}'),
            child: _FieldRow(
              row: row,
              field: widget.fields[row],
              onEdit: (field) => _edit(row, field),
              onReplace: (field) => _replace(row, field),
              onChoose: () => _choose(row),
              onRemove: () => _remove(row),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('add-multipart-field'),
            onPressed: _add,
            icon: const Icon(Icons.add, size: 16),
            label: Text(context.l10n.multipartAddField),
          ),
        ),
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.row,
    required this.field,
    required this.onEdit,
    required this.onReplace,
    required this.onChoose,
    required this.onRemove,
  });

  final int row;
  final MultipartField field;
  final ValueChanged<MultipartField> onEdit;
  final ValueChanged<MultipartField> onReplace;
  final VoidCallback onChoose;
  final VoidCallback onRemove;

  bool get _isFile => field.kind == MultipartFieldKind.file;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                key: ValueKey('multipart-enabled-$row'),
                value: field.enabled,
                onChanged: (value) => onEdit(field.copyWith(enabled: value ?? true)),
              ),
              Expanded(
                flex: 2,
                child: TextFormField(
                  key: ValueKey('multipart-name-$row'),
                  initialValue: field.name,
                  decoration: InputDecoration(hintText: context.l10n.multipartNameHint, isDense: true),
                  onChanged: (value) => onEdit(field.copyWith(name: value)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              DropdownButtonHideUnderline(
                child: DropdownButton<MultipartFieldKind>(
                  key: ValueKey('multipart-kind-$row'),
                  value: field.kind,
                  isDense: true,
                  items: [
                    DropdownMenuItem(value: MultipartFieldKind.text, child: Text(context.l10n.multipartText)),
                    DropdownMenuItem(value: MultipartFieldKind.file, child: Text(context.l10n.multipartFile)),
                  ],
                  onChanged: (kind) {
                    // A text value is not a path and a path is not text: start clean.
                    if (kind != null && kind != field.kind) onReplace(MultipartField(name: field.name, kind: kind, enabled: field.enabled));
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (_isFile) ...[
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    key: ValueKey('multipart-path-$row'),
                    initialValue: field.value,
                    decoration: InputDecoration(hintText: context.l10n.multipartPathHint, isDense: true),
                    onChanged: (value) => onEdit(field.copyWith(value: value)),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                OutlinedButton(
                  key: ValueKey('multipart-choose-$row'),
                  onPressed: onChoose,
                  child: Text(context.l10n.multipartChoose),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: ValueKey('multipart-type-$row'),
                    initialValue: field.contentType ?? '',
                    decoration: InputDecoration(hintText: context.l10n.multipartAutoHint, isDense: true),
                    // Empty means "work it out from the extension", which is null.
                    onChanged: (value) => onEdit(
                      value.isEmpty ? field.copyWith(contentType: null) : field.copyWith(contentType: value),
                    ),
                  ),
                ),
              ] else
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    key: ValueKey('multipart-value-$row'),
                    initialValue: field.value,
                    decoration: InputDecoration(hintText: context.l10n.multipartValueHint, isDense: true),
                    onChanged: (value) => onEdit(field.copyWith(value: value)),
                  ),
                ),
              IconButton(
                key: ValueKey('multipart-remove-$row'),
                icon: const Icon(Icons.close, size: 16),
                onPressed: onRemove,
              ),
            ],
          ),
          if (_isFile && field.enabled && field.value.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 2),
              child: Text(
                context.l10n.multipartNoFile,
                key: ValueKey('multipart-no-file-$row'),
                style: AppTypography.bodySm.copyWith(color: AppColors.warning),
              ),
            ),
        ],
      ),
    );
  }
}
