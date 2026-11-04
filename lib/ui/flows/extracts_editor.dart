import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The `name ← response.path` rows of a step's [FlowStep.extract], editable:
/// add, rename, change the path, remove. With [knownPaths] (the paths of the
/// step's last response), a path that is not among them is flagged: the run
/// would leave that variable unset.
class ExtractsEditor extends StatefulWidget {
  const ExtractsEditor({
    super.key,
    required this.stepIndex,
    required this.extract,
    required this.onChanged,
    this.knownPaths,
  });

  final int stepIndex;
  final Map<String, String> extract;
  final ValueChanged<Map<String, String>> onChanged;
  final Set<String>? knownPaths;

  @override
  State<ExtractsEditor> createState() => _ExtractsEditorState();
}

class _ExtractsEditorState extends State<ExtractsEditor> {
  late List<(TextEditingController, TextEditingController)> _rows = _rowsFor(widget.extract);

  /// The map this editor last handed to [ExtractsEditor.onChanged], to tell its
  /// own edits (which must keep focus and cursor) apart from a change made
  /// elsewhere -- a field dragged onto an input, another step in this place.
  Map<String, String>? _emitted;

  List<(TextEditingController, TextEditingController)> _rowsFor(Map<String, String> extract) => [
        for (final entry in extract.entries)
          (TextEditingController(text: entry.key), TextEditingController(text: entry.value)),
      ];

  @override
  void didUpdateWidget(ExtractsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final mine = mapEquals(widget.extract, _emitted);
    if (!mine && !mapEquals(widget.extract, oldWidget.extract) || widget.extract.length != _rows.length) {
      _dispose(_rows);
      _rows = _rowsFor(widget.extract);
    }
  }

  @override
  void dispose() {
    _dispose(_rows);
    super.dispose();
  }

  void _dispose(List<(TextEditingController, TextEditingController)> rows) {
    for (final (name, path) in rows) {
      name.dispose();
      path.dispose();
    }
  }

  void _emit() {
    final next = {for (final (name, path) in _rows) name.text: path.text};
    _emitted = next;
    widget.onChanged(next);
  }

  void _add() {
    var name = 'variable';
    var suffix = 1;
    final taken = {for (final (n, _) in _rows) n.text};
    while (taken.contains(name)) {
      name = 'variable_$suffix';
      suffix++;
    }
    setState(() => _rows = [..._rows, (TextEditingController(text: name), TextEditingController())]);
    _emit();
  }

  void _remove(int row) {
    final removed = _rows[row];
    setState(() => _rows = [..._rows]..removeAt(row));
    _emit();
    WidgetsBinding.instance.addPostFrameCallback((_) => _dispose([removed]));
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.stepIndex;
    final known = widget.knownPaths;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.stepExtractTitle, style: Theme.of(context).textTheme.labelMedium),
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: ValueKey('extract-name-$step-$i'),
                        controller: _rows[i].$1,
                        decoration: const InputDecoration(hintText: 'variable_name', isDense: true),
                        onChanged: (_) => _emit(),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: Text('←'),
                    ),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        key: ValueKey('extract-path-$step-$i'),
                        controller: _rows[i].$2,
                        decoration: const InputDecoration(hintText: 'response.body.x.y', isDense: true),
                        onChanged: (_) => setState(_emit),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('remove-extract-$step-$i'),
                      icon: const Icon(Icons.close, size: 14),
                      onPressed: () => _remove(i),
                    ),
                  ],
                ),
                if (known != null && _rows[i].$2.text.trim().isNotEmpty && !known.contains(_rows[i].$2.text.trim()))
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      context.l10n.panelExtractNotInResponse,
                      style: AppTypography.bodySm.copyWith(color: AppColors.warning),
                    ),
                  ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: ValueKey('add-extract-$step'),
            onPressed: _add,
            icon: const Icon(Icons.add, size: 14),
            label: Text(context.l10n.stepAddExtracted),
          ),
        ),
      ],
    );
  }
}
