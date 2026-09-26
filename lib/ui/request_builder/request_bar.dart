import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'request_draft_provider.dart';
import 'send_provider.dart';

const _methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

/// First vertical slice of the request builder: a method dropdown, a URL
/// field, a Send button wired to the real [RequestExecutor], and a plain
/// status/body view of the result. Params/Headers/Body/Auth tabs and
/// environment-variable interpolation come in later tasks (2.4, 3.3).
class RequestBar extends ConsumerWidget {
  const RequestBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(requestDraftProvider);
    final sendState = ref.watch(sendStateProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DropdownButton<String>(
                value: draft.method,
                items: [
                  for (final method in _methods) DropdownMenuItem(value: method, child: Text(method)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(requestDraftProvider.notifier).setMethod(value);
                  }
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('request-url-field'),
                  decoration: const InputDecoration(hintText: 'https://api.example.com/users'),
                  onChanged: (value) => ref.read(requestDraftProvider.notifier).setUrl(value),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: sendState.loading
                    ? null
                    : () => ref.read(sendStateProvider.notifier).send(),
                child: sendState.loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: _ResponseArea(sendState: sendState)),
        ],
      ),
    );
  }
}

class _ResponseArea extends StatelessWidget {
  const _ResponseArea({required this.sendState});

  final SendState sendState;

  @override
  Widget build(BuildContext context) {
    final response = sendState.response;
    if (response == null) {
      return const Center(child: Text('Send a request to see the response'));
    }
    if (response.error != null) {
      return Center(
        key: const Key('response-error'),
        child: Text('Error: ${response.error}'),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${response.status} • ${response.elapsedMs}ms • ${response.sizeBytes}B',
            key: const Key('response-meta'),
          ),
          const SizedBox(height: 8),
          Text('${response.body}', key: const Key('response-body')),
        ],
      ),
    );
  }
}
