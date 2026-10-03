import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/collections_provider.dart';
import '../history/history_tab.dart';
import 'request_draft_provider.dart';
import 'send_provider.dart';
import 'tabs/auth_tab.dart';
import 'tabs/body_tab.dart';
import 'tabs/docs_tab.dart';
import 'tabs/headers_tab.dart';
import 'tabs/params_tab.dart';
import 'url_field.dart';

const _methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

/// The request builder: a method dropdown, a URL field, a Send button
/// wired to the real [RequestExecutor], Params/Headers/Body/Auth/Docs tabs
/// (Tests/Settings are out of MVP scope -- stub placeholders). The response
/// lives in its own pane, see `WorkspaceScreen`.
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
              const Expanded(child: UrlField()),
              const SizedBox(width: 12),
              OutlinedButton(
                key: const Key('save-request-button'),
                // Only a draft that already came from a saved Endpoint (via
                // the sidebar's "+ Add request", which creates-then-loads
                // it) can be saved -- there's no group to save an
                // unassociated blank draft into. See sidebar_tree.dart.
                onPressed: draft.id == draftEndpointId
                    ? null
                    : () => ref.read(collectionsProvider.notifier).updateEndpoint(draft),
                child: const Text('Save'),
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
              length: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      Tab(text: 'Docs'),
                      Tab(text: 'Params'),
                      Tab(text: 'Headers'),
                      Tab(text: 'Body'),
                      Tab(text: 'Auth'),
                      Tab(text: 'History'),
                      Tab(text: 'Tests'),
                      Tab(text: 'Settings'),
                    ],
                  ),
                  const Expanded(
                    child: TabBarView(
                      children: [
                        DocsTab(),
                        ParamsTab(),
                        HeadersTab(),
                        BodyTab(),
                        AuthTab(),
                        HistoryTab(),
                        Center(child: Text('Tests are out of MVP scope')),
                        Center(child: Text('Settings are out of MVP scope')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
