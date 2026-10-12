import 'package:flutter/material.dart' hide Flow;

import '../../engine/models/models.dart';
import '../../l10n/l10n.dart';

/// Asks which of [flows] to export or import: one checkbox each and an "All flows" one
/// on top. Everything starts selected. Returns the chosen ids, or null when cancelled;
/// the confirm button is off while nothing is chosen.
Future<Set<String>?> showFlowSelectionDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required List<Flow> flows,
}) =>
    showDialog<Set<String>>(
      context: context,
      builder: (context) => _FlowSelectionDialog(title: title, confirmLabel: confirmLabel, flows: flows),
    );

class _FlowSelectionDialog extends StatefulWidget {
  const _FlowSelectionDialog({required this.title, required this.confirmLabel, required this.flows});

  final String title;
  final String confirmLabel;
  final List<Flow> flows;

  @override
  State<_FlowSelectionDialog> createState() => _FlowSelectionDialogState();
}

class _FlowSelectionDialogState extends State<_FlowSelectionDialog> {
  late final Set<String> _selected = {for (final f in widget.flows) f.id};

  bool get _all => _selected.length == widget.flows.length;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('flow-selection-dialog'),
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              key: const Key('flow-selection-all'),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(context.l10n.flowsSelectAll),
              value: _all ? true : (_selected.isEmpty ? false : null),
              tristate: true,
              onChanged: (_) => setState(() {
                if (_all) {
                  _selected.clear();
                } else {
                  _selected.addAll(widget.flows.map((f) => f.id));
                }
              }),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final flow in widget.flows)
                    CheckboxListTile(
                      key: ValueKey('flow-selection-${flow.id}'),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(flow.name, overflow: TextOverflow.ellipsis),
                      subtitle: Text(context.l10n.flowsStepCount(flow.steps.length)),
                      value: _selected.contains(flow.id),
                      onChanged: (checked) => setState(() {
                        if (checked ?? false) {
                          _selected.add(flow.id);
                        } else {
                          _selected.remove(flow.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('flow-selection-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('flow-selection-confirm'),
          onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop({..._selected}),
          child: Text('${widget.confirmLabel} (${_selected.length})'),
        ),
      ],
    );
  }
}
