import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/collections_provider.dart';
import '../theme/widgets/pill_tab_bar.dart';
import 'method_selector.dart';
import 'request_draft_provider.dart';
import 'request_header.dart';
import 'save_draft_dialog.dart';
import 'send_provider.dart';
import 'tabs/auth_tab.dart';
import 'tabs/body_tab.dart';
import 'tabs/docs_tab.dart';
import 'tabs/headers_tab.dart';
import 'tabs/params_tab.dart';
import 'url_field.dart';
import '../../l10n/l10n.dart';

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
          const RequestHeader(),
          const SizedBox(height: 12),
          Row(
            children: [
              const MethodSelector(),
              const SizedBox(width: 12),
              const Expanded(child: UrlField()),
              const SizedBox(width: 12),
              OutlinedButton(
                key: const Key('save-request-button'),
                // A saved request is updated in place; an unsaved draft (a
                // pasted curl) asks for the folder to go in first.
                onPressed: draft.id == draftEndpointId
                    ? () => saveDraftToFolder(context, ref)
                    : () => ref.read(collectionsProvider.notifier).updateEndpoint(draft),
                child: Text(context.l10n.commonSave),
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
                    : Text(context.l10n.commonSend),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: DefaultTabController(
              length: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PillTabBar(
                    labels: [
                      context.l10n.requestTabDocs,
                      context.l10n.requestTabParams,
                      context.l10n.requestTabHeaders,
                      context.l10n.requestTabBody,
                      context.l10n.requestTabAuth,
                      context.l10n.requestTabTests,
                      context.l10n.requestTabSettings,
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        DocsTab(),
                        ParamsTab(),
                        HeadersTab(),
                        BodyTab(),
                        AuthTab(),
                        Center(child: Text(context.l10n.requestTestsOutOfScope)),
                        Center(child: Text(context.l10n.requestSettingsOutOfScope)),
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
