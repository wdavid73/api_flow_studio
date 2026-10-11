import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../engine/models/models.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The list of a step's assertions: one row per assertion (field, operator,
/// expected value, remove) and an "Add assertion" button.
///
/// The text fields only read their `initialValue` once, so each row gets an id
/// of its own: removing a row rebuilds the ones after it instead of leaving
/// them showing the removed row's text.
class AssertionsEditor extends StatefulWidget {
  const AssertionsEditor({
    super.key,
    required this.stepIndex,
    required this.assertions,
    required this.onChanged,
  });

  final int stepIndex;
  final List<Assertion> assertions;
  final ValueChanged<List<Assertion>> onChanged;

  @override
  State<AssertionsEditor> createState() => _AssertionsEditorState();
}

class _AssertionsEditorState extends State<AssertionsEditor> {
  var _nextId = 0;
  late List<int> _ids = _freshIds(widget.assertions.length);

  /// The list this editor last handed to [AssertionsEditor.onChanged], to tell
  /// its own edits apart from a different step arriving in the same place.
  List<Assertion>? _emitted;

  List<int> _freshIds(int count) => [for (var i = 0; i < count; i++) _nextId++];

  @override
  void didUpdateWidget(AssertionsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A change this editor did not make (steps reordered, another flow opened,
    // a reload): the rows now show someone else's assertions, so rebuild them.
    final mine = listEquals(widget.assertions, _emitted);
    if (widget.assertions.length != _ids.length ||
        (!mine && !listEquals(widget.assertions, oldWidget.assertions))) {
      _ids = _freshIds(widget.assertions.length);
    }
  }

  void _emit(List<Assertion> next) {
    _emitted = next;
    widget.onChanged(next);
  }

  void _replace(int row, Assertion assertion) {
    final next = [...widget.assertions];
    next[row] = assertion;
    _emit(next);
  }

  void _remove(int row) {
    setState(() => _ids = [..._ids]..removeAt(row));
    _emit([...widget.assertions]..removeAt(row));
  }

  void _add() {
    setState(() => _ids = [..._ids, _nextId++]);
    // The first assertion starts from the check people almost always want.
    final created = widget.assertions.isEmpty
        ? const Assertion(field: 'response.status', expected: '200')
        : const Assertion(field: '');
    _emit([...widget.assertions, created]);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.stepIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Assertions', style: AppTypography.labelMd),
        for (var row = 0; row < widget.assertions.length; row++)
          KeyedSubtree(
            key: ValueKey('assertion-row-${_ids[row]}'),
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _AssertionRow(
                step: step,
                row: row,
                assertion: widget.assertions[row],
                onChanged: (assertion) => _replace(row, assertion),
                onRemove: () => _remove(row),
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('add-assertion-$step'),
            onPressed: _add,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Add assertion'),
          ),
        ),
      ],
    );
  }
}

class _AssertionRow extends StatelessWidget {
  const _AssertionRow({
    required this.step,
    required this.row,
    required this.assertion,
    required this.onChanged,
    required this.onRemove,
  });

  final int step;
  final int row;
  final Assertion assertion;
  final ValueChanged<Assertion> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextFormField(
            key: ValueKey('assertion-field-$step-$row'),
            initialValue: assertion.field,
            decoration: const InputDecoration(hintText: 'response.status', isDense: true),
            onChanged: (value) => onChanged(assertion.copyWith(field: value)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        DropdownButtonHideUnderline(
          child: DropdownButton<AssertionOperator>(
            key: ValueKey('assertion-operator-$step-$row'),
            value: assertion.operator,
            isDense: true,
            items: [
              for (final op in AssertionOperator.values)
                DropdownMenuItem(value: op, child: Text(op.label, style: AppTypography.codeMd)),
            ],
            onChanged: (op) {
              if (op != null) onChanged(assertion.copyWith(operator: op));
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          // Hidden, not cleared: switching back to == finds the text again.
          child: assertion.operator.takesExpected
              ? TextFormField(
                  key: ValueKey('assertion-expected-$step-$row'),
                  initialValue: assertion.expected,
                  decoration: const InputDecoration(hintText: 'expected', isDense: true),
                  onChanged: (value) => onChanged(assertion.copyWith(expected: value)),
                )
              : const SizedBox.shrink(),
        ),
        IconButton(
          key: ValueKey('remove-assertion-$step-$row'),
          icon: const Icon(Icons.close, size: 14),
          onPressed: onRemove,
        ),
      ],
    );
  }
}
