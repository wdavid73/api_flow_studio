import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/models/models.dart';
import '../session/session_provider.dart';
import 'request_draft_provider.dart';
import 'variable_highlighting_controller.dart';

/// The request builder's URL field. Highlights `{{variable}}` occurrences
/// against the active environment (cyan resolved / amber unresolved) --
/// this is display-only coloring; `{{var}}` stays literal text the user
/// can freely edit, per SPEC criterion #2/#3.
class UrlField extends ConsumerStatefulWidget {
  const UrlField({super.key});

  @override
  ConsumerState<UrlField> createState() => _UrlFieldState();
}

class _UrlFieldState extends ConsumerState<UrlField> {
  late final VariableHighlightingController _controller;
  late String _loadedEndpointId;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(requestDraftProvider);
    _controller = VariableHighlightingController(text: draft.url);
    _loadedEndpointId = draft.id;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The field's own onChanged is the source of truth while editing the
    // *current* draft (identity unchanged) -- don't fight the user's
    // typing/cursor. Only resync the controller's text when a genuinely
    // different endpoint gets loaded (sidebar click, or reset), which the
    // field itself has no other way to learn about.
    ref.listen<Endpoint>(requestDraftProvider, (previous, next) {
      if (next.id != _loadedEndpointId) {
        _loadedEndpointId = next.id;
        _controller.text = next.url;
      }
    });

    final activeVariables = ref.watch(effectiveVariablesProvider);
    _controller.updateResolvedVariables(activeVariables);

    return TextField(
      key: const Key('request-url-field'),
      controller: _controller,
      decoration: const InputDecoration(hintText: 'https://api.example.com/users'),
      onChanged: (value) => ref.read(requestDraftProvider.notifier).setUrl(value),
    );
  }
}
