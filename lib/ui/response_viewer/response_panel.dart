import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/curl/curl_builder.dart';
import '../../engine/session/session_apply.dart';
import '../../engine/http/executed_response.dart';
import '../history/history_tab.dart';
import '../request_builder/request_draft_provider.dart';
import '../request_builder/send_provider.dart';
import '../session/session_provider.dart';
import '../shell/app_toast.dart';
import '../shell/header_ghost_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/widgets/pill_tab_bar.dart';
import '../theme/widgets/status_badge.dart';
import 'response_body_tab.dart';
import 'response_cookies_tab.dart';
import 'response_headers_tab.dart';
import 'response_timeline_tab.dart';
import '../../l10n/l10n.dart';
import '../platform/platform_capabilities.dart';
import 'browser_hint.dart';

/// The response side of the workspace: Response / History tabs with Copy and
/// curl buttons beside them. Response shows a status line
/// (`200 · 124 ms · 512 B`) over a Body | Headers | Cookies | Timeline tab set. `Copy` takes the raw body; `curl` builds a curl command for the
/// request currently in the builder with the active environment resolved.
class ResponsePanel extends ConsumerWidget {
  const ResponsePanel({super.key, required this.sendState});

  final SendState sendState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final response = sendState.response;

    final copyButton = HeaderGhostButton(
          key: const Key('copy-body-button'),
          label: context.l10n.responseCopy,
          onPressed: () {
            if (response == null || response.error != null) {
              showToast(ref, context.l10n.responseNothingToCopy);
              return;
            }
            Clipboard.setData(ClipboardData(text: rawResponseBody(response.body)));
            showToast(ref, context.l10n.responseCopied);
          },
        );
    final curlButton = HeaderGhostButton(
          key: const Key('copy-curl-button'),
          label: 'curl',
          onPressed: () {
            // The same request the app would send: with the session's Bearer
            // token (unless the request sets its own auth) and its variables.
            final request = applySession(ref.read(requestDraftProvider), ref.read(activeSessionProvider));
            Clipboard.setData(ClipboardData(text: buildCurl(request, variables: ref.read(effectiveVariablesProvider))));
            showToast(ref, context.l10n.responseCurlCopied);
          },
        );

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Align(alignment: Alignment.centerLeft, child: PillTabBar(labels: [context.l10n.responseTabResponse, context.l10n.responseTabHistory]))),
              copyButton,
              const SizedBox(width: AppSpacing.sm),
              curlButton,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: TabBarView(
              children: [
                _ResponseView(response: response),
                const HistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The Response tab: empty/error states, or the status line plus the
/// Body | Headers | Cookies | Timeline tab set.
class _ResponseView extends ConsumerWidget {
  const _ResponseView({required this.response});

  final ExecutedResponse? response;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final response = this.response;

    if (response == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n.responseNone, style: AppTypography.codeLg),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.l10n.responseNoneHint,
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      );
    }
    if (response.error != null) {
      final hint = browserNetworkHint(
        context.l10n,
        isBrowser: ref.watch(platformCapabilitiesProvider).isBrowser,
        url: response.requestUrl,
      );
      return Center(
        key: const Key('response-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.responseErrorWithMessage('${response.error}')),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  hint,
                  key: const Key('response-browser-hint'),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(color: AppColors.warning),
                ),
              ),
          ],
        ),
      );
    }

    final dot = Text('·', style: AppTypography.codeMd.copyWith(color: AppColors.outline));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            StatusBadge(statusCode: response.status ?? 0),
            const SizedBox(width: AppSpacing.sm),
            dot,
            const SizedBox(width: AppSpacing.sm),
            Text(context.l10n.commonTimeMs(response.elapsedMs), key: const Key('response-elapsed'), style: AppTypography.codeMd),
            const SizedBox(width: AppSpacing.sm),
            dot,
            const SizedBox(width: AppSpacing.sm),
            Text(context.l10n.commonSizeBytes(response.sizeBytes), key: const Key('response-size'), style: AppTypography.codeMd),
          ],
        ),
        Expanded(
          child: DefaultTabController(
            length: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: context.l10n.responseTabBody),
                    Tab(text: context.l10n.responseTabHeaders),
                    Tab(text: context.l10n.responseTabCookies),
                    Tab(text: context.l10n.responseTabTimeline),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      ResponseBodyTab(body: response.body),
                      ResponseHeadersTab(headers: response.headers),
                      ResponseCookiesTab(headers: response.headers),
                      ResponseTimelineTab(elapsedMs: response.elapsedMs),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
