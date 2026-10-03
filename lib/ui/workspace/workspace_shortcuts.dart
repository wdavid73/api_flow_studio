import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/sidebar_tree.dart';
import '../request_builder/send_provider.dart';

/// Workspace keyboard shortcuts:
///  * Ctrl/Cmd + Enter sends the current request (ignored while a send is
///    already running); it works even while typing in a text field.
///  * `/` focuses the sidebar search, but only when no text field has focus,
///    so typing a slash into the URL or a body is never swallowed.
class WorkspaceShortcuts extends ConsumerWidget {
  const WorkspaceShortcuts({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final keyboard = HardwareKeyboard.instance;
        final modifier = keyboard.isControlPressed || keyboard.isMetaPressed;
        final key = event.logicalKey;

        if (modifier && (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter)) {
          if (!ref.read(sendStateProvider).loading) {
            ref.read(sendStateProvider.notifier).send();
          }
          return KeyEventResult.handled;
        }

        if (!modifier && key == LogicalKeyboardKey.slash && !_isTyping()) {
          ref.read(sidebarSearchFocusNodeProvider).requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }

  /// True when the focused widget is an editable text field.
  bool _isTyping() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}
