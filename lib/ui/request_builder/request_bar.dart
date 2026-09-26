import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../response_viewer/response_panel.dart';
import 'request_draft_provider.dart';
import 'send_provider.dart';
import 'tabs/auth_tab.dart';
import 'tabs/body_tab.dart';
import 'tabs/headers_tab.dart';
import 'tabs/params_tab.dart';

const _methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

/// The request builder: a method dropdown, a URL field, a Send button
/// wired to the real [RequestExecutor], Params/Headers/Body/Auth tabs
/// (Tests/Settings are out of MVP scope -- stub placeholders), and a plain
/// status/body view of the result. Environment-variable interpolation
/// comes in Task 3.3.
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
          Expanded(
            child: DefaultTabController(
              length: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(text: 'Params'),
                      Tab(text: 'Headers'),
                      Tab(text: 'Body'),
                      Tab(text: 'Auth'),
                      Tab(text: 'Tests'),
                      Tab(text: 'Settings'),
                    ],
                  ),
                  const Expanded(
                    child: TabBarView(
                      children: [
                        ParamsTab(),
                        HeadersTab(),
                        BodyTab(),
                        AuthTab(),
                        Center(child: Text('Tests are out of MVP scope')),
                        Center(child: Text('Settings are out of MVP scope')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: ResponsePanel(sendState: sendState)),
        ],
      ),
    );
  }
}
