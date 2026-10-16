import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../../l10n/l10n.dart';
import '../environments/environments_provider.dart';
import '../session/session_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

final RegExp _tokenPattern = RegExp(r'\{\{(\w+)\}\}');

/// Wraps a text field: hovering a `{{variable}}` in it opens a small card with the
/// variable's value in an input, editable on the spot. The value is read from and
/// written to the active environment, so what is typed here is what Send uses next.
///
/// The text and its layout come from the field's own [RenderEditable], so this works
/// with any field (and any controller) without being told what is inside.
class VariableHover extends ConsumerStatefulWidget {
  const VariableHover({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<VariableHover> createState() => _VariableHoverState();
}

class _VariableHoverState extends ConsumerState<VariableHover> {
  static const _closeDelay = Duration(milliseconds: 250);

  OverlayEntry? _entry;
  String? _shownName;
  Timer? _closeTimer;
  bool _editing = false;

  @override
  void dispose() {
    _closeTimer?.cancel();
    _entry?.remove();
    _entry = null;
    super.dispose();
  }

  RenderEditable? _findEditable() {
    RenderEditable? found;
    void visit(RenderObject object) {
      if (found != null) return;
      if (object is RenderEditable) {
        found = object;
        return;
      }
      object.visitChildren(visit);
    }

    final root = context.findRenderObject();
    if (root != null) visit(root);
    return found;
  }

  /// The variable under [globalPosition] and the screen rectangle of its text.
  ({String name, Rect rect})? _tokenAt(Offset globalPosition) {
    final editable = _findEditable();
    if (editable == null || !editable.attached) return null;
    final text = editable.text?.toPlainText() ?? '';
    if (!text.contains('{{')) return null;

    final offset = editable.getPositionForPoint(globalPosition).offset;
    final local = editable.globalToLocal(globalPosition);
    for (final match in _tokenPattern.allMatches(text)) {
      if (offset < match.start || offset > match.end) continue;
      final boxes = editable.getBoxesForSelection(TextSelection(baseOffset: match.start, extentOffset: match.end));
      for (final box in boxes) {
        final rect = box.toRect();
        if (rect.inflate(2).contains(local)) {
          final topLeft = editable.localToGlobal(rect.topLeft);
          return (name: match.group(1)!, rect: topLeft & rect.size);
        }
      }
    }
    return null;
  }

  void _onHover(PointerHoverEvent event) {
    final token = _tokenAt(event.position);
    if (token == null) {
      _scheduleClose();
      return;
    }
    _closeTimer?.cancel();
    if (_entry != null && _shownName == token.name) return;
    if (_editing) return; // typing a value: don't swap the card under the user's hands
    _show(token.name, token.rect);
  }

  void _scheduleClose() {
    if (_entry == null) return;
    _closeTimer?.cancel();
    _closeTimer = Timer(_closeDelay, () {
      if (!_editing) _close();
    });
  }

  void _close() {
    _closeTimer?.cancel();
    _entry?.remove();
    _entry = null;
    _shownName = null;
    _editing = false;
  }

  void _show(String name, Rect anchor) {
    _entry?.remove();
    _shownName = name;
    _entry = OverlayEntry(
      builder: (context) => _VariableCard(
        name: name,
        anchor: anchor,
        onPointerInside: () => _closeTimer?.cancel(),
        onPointerOutside: _scheduleClose,
        onEditingChanged: (editing) {
          _editing = editing;
          if (!editing) _scheduleClose();
        },
        onDismiss: _close,
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: _onHover,
      onExit: (_) => _scheduleClose(),
      child: widget.child,
    );
  }
}

class _VariableCard extends ConsumerStatefulWidget {
  const _VariableCard({
    required this.name,
    required this.anchor,
    required this.onPointerInside,
    required this.onPointerOutside,
    required this.onEditingChanged,
    required this.onDismiss,
  });

  final String name;
  final Rect anchor;
  final VoidCallback onPointerInside;
  final VoidCallback onPointerOutside;
  final ValueChanged<bool> onEditingChanged;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_VariableCard> createState() => _VariableCardState();
}

class _VariableCardState extends ConsumerState<_VariableCard> {
  static const _width = 280.0;

  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    final variable = ref.read(environmentsProvider).value?.active?.variables[widget.name];
    // A `session_*` variable has no environment to live in: it is shown, not edited.
    _controller = TextEditingController(text: variable?.value ?? ref.read(effectiveVariablesProvider)[widget.name] ?? '');
    _focus.addListener(() => widget.onEditingChanged(_focus.hasFocus));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save(String value) {
    final active = ref.read(environmentsProvider).value?.active;
    if (active == null) return Future.value();
    final current = active.variables[widget.name] ?? const EnvironmentVariable(value: '');
    return ref.read(environmentsProvider.notifier).updateEnvironment(active.copyWith(
      variables: {...active.variables, widget.name: current.copyWith(value: value)},
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = ref.watch(environmentsProvider.select((s) => s.value?.active));
    final variable = active?.variables[widget.name];
    final readOnly = active == null || (variable == null && widget.name.startsWith('session_'));

    final screen = MediaQuery.sizeOf(context);
    final maxLeft = (screen.width - _width - AppSpacing.sm).clamp(AppSpacing.sm, double.infinity);
    final left = widget.anchor.left.clamp(AppSpacing.sm, maxLeft);
    final top = widget.anchor.bottom + 4;

    final hint = active == null
        ? l10n.variableTooltipNoEnvironment
        : variable == null
            ? l10n.variableTooltipUnresolved
            : l10n.variableTooltipHint;

    return Positioned(
      left: left,
      top: top,
      width: _width,
      child: TextFieldTapRegion(
        child: MouseRegion(
          onEnter: (_) => widget.onPointerInside(),
          onExit: (_) => widget.onPointerOutside(),
          child: CallbackShortcuts(
            bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.onDismiss},
            child: Material(
              key: const Key('variable-hover-card'),
              color: AppColors.surfaceContainerHigh,
              elevation: 6,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '{{${widget.name}}}',
                      style: AppTypography.codeSm.copyWith(
                        color: variable == null ? AppColors.variableUnresolvedText : AppColors.variableResolvedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextField(
                      key: const Key('variable-hover-field'),
                      controller: _controller,
                      focusNode: _focus,
                      enabled: !readOnly,
                      obscureText: variable?.secret ?? false,
                      style: AppTypography.codeMd,
                      decoration: const InputDecoration(isDense: true),
                      onChanged: _save,
                      onSubmitted: (_) => widget.onDismiss(),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(hint, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
