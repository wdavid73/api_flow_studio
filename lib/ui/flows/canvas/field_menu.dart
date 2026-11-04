import 'package:flutter/material.dart' hide Flow;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../engine/flows/variable_naming.dart';
import '../../../engine/models/models.dart';
import '../../../l10n/l10n.dart';
import '../../shell/app_toast.dart';
import '../flows_provider.dart';
import '../flows_screen.dart' show selectedStepIndexProvider, stepPanelTabProvider;
import 'step_panel.dart';

enum _FieldAction { useAsVariable, addAssertion, copyPath }

/// The menu of a response value of step [stepIndex] (a field on its node, or
/// any value of the panel's response tree), opened at [position]:
/// - Use as variable… -- asks for a name (suggested from [path]) and adds the
///   extract, so any later step using `{{name}}` is fed by it;
/// - Add assertion -- adds `path exists` to the step and opens its panel there;
/// - Copy path -- puts the full path on the clipboard.
Future<void> showFieldMenu(
  BuildContext context,
  WidgetRef ref, {
  required Flow flow,
  required int stepIndex,
  required String path,
  required Offset position,
}) async {
  final l10n = context.l10n;
  final action = await showMenu<_FieldAction>(
    context: context,
    position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
    items: [
      PopupMenuItem(
        key: const Key('field-menu-use-as-variable'),
        value: _FieldAction.useAsVariable,
        child: Text(l10n.fieldUseAsVariable),
      ),
      PopupMenuItem(
        key: const Key('field-menu-add-assertion'),
        value: _FieldAction.addAssertion,
        child: Text(l10n.assertionsAdd),
      ),
      PopupMenuItem(key: const Key('field-menu-copy-path'), value: _FieldAction.copyPath, child: Text(l10n.fieldCopyPath)),
    ],
  );
  if (action == null || !context.mounted) return;

  final flows = ref.read(flowsProvider.notifier);
  // The flow as it is now: it may have changed while the menu was open.
  FlowStep? current() =>
      ref.read(flowsProvider).value?.where((f) => f.id == flow.id).firstOrNull?.steps.elementAtOrNull(stepIndex);

  switch (action) {
    case _FieldAction.useAsVariable:
      final name = await showDialog<String>(
        context: context,
        builder: (_) => _VariableNameDialog(initial: suggestVariableName(path)),
      );
      final step = current();
      if (name == null || step == null) return;
      await flows.updateStep(flow.id, stepIndex, step.copyWith(extract: {...step.extract, name: path}));
    case _FieldAction.addAssertion:
      final step = current();
      if (step == null) return;
      await flows.updateStep(
        flow.id,
        stepIndex,
        step.copyWith(assertions: [...step.assertions, Assertion(field: path, operator: AssertionOperator.exists)]),
      );
      ref.read(stepPanelTabProvider.notifier).state = StepPanelTab.step;
      ref.read(selectedStepIndexProvider.notifier).state = stepIndex;
    case _FieldAction.copyPath:
      await Clipboard.setData(ClipboardData(text: path));
      showToast(ref, l10n.fieldPathCopied);
  }
}

/// Asks for the name a value is extracted as; only a name `{{name}}` can
/// resolve (letters, digits and `_`) can be confirmed.
class _VariableNameDialog extends StatefulWidget {
  const _VariableNameDialog({required this.initial});

  final String initial;

  @override
  State<_VariableNameDialog> createState() => _VariableNameDialogState();
}

class _VariableNameDialogState extends State<_VariableNameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _controller.text;
    final valid = isValidVariableName(name);
    void confirm() => Navigator.of(context).pop(name);

    return AlertDialog(
      title: Text(context.l10n.variableNameTitle),
      content: TextField(
        key: const Key('variable-name-field'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          prefixText: '{{',
          suffixText: '}}',
          errorText: valid ? null : context.l10n.variableNameInvalid,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: valid ? (_) => confirm() : null,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.commonCancel)),
        TextButton(
          key: const Key('variable-name-confirm'),
          onPressed: valid ? confirm : null,
          child: Text(context.l10n.commonSave),
        ),
      ],
    );
  }
}
