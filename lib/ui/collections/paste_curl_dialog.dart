import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/curl/curl_parser.dart';
import '../request_builder/request_draft_provider.dart';

/// Opens a dialog with a multi-line paste field; on a successful parse,
/// loads the result into the request builder as a new unsaved draft (the
/// user still explicitly picks a group and saves it via the existing
/// sidebar "Add request" flow).
Future<void> showPasteCurlDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _PasteCurlDialog(),
  );
}

class _PasteCurlDialog extends ConsumerStatefulWidget {
  const _PasteCurlDialog();

  @override
  ConsumerState<_PasteCurlDialog> createState() => _PasteCurlDialogState();
}

class _PasteCurlDialogState extends ConsumerState<_PasteCurlDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final parsed = parseCurl(_controller.text);
      ref.read(requestDraftProvider.notifier).loadEndpoint(parsed.copyWith(id: draftEndpointId));
      Navigator.of(context).pop();
    } on CurlParseException catch (e) {
      setState(() => _error = "Couldn't parse this curl command: ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paste curl'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('paste-curl-field'),
              controller: _controller,
              maxLines: 8,
              minLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "curl 'https://api.example.com/users' -H '...' -d '...'",
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const Key('paste-curl-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancel-paste-curl-button'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirm-paste-curl-button'),
          onPressed: _submit,
          child: const Text('Import'),
        ),
      ],
    );
  }
}
