import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../environments/environments_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = VariableHighlightingController(text: ref.read(requestDraftProvider).url);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeVariables =
        ref.watch(environmentsProvider).value?.active?.resolvedVariables ?? const {};
    _controller.updateResolvedVariables(activeVariables);

    return TextField(
      key: const Key('request-url-field'),
      controller: _controller,
      decoration: const InputDecoration(hintText: 'https://api.example.com/users'),
      onChanged: (value) => ref.read(requestDraftProvider.notifier).setUrl(value),
    );
  }
}
