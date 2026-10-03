import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/curl/curl_builder.dart';
import '../environments/environments_provider.dart';
import '../request_builder/request_draft_provider.dart';
import '../request_builder/send_provider.dart';
import '../shell/app_toast.dart';
import '../shell/header_ghost_button.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/widgets/status_badge.dart';
import 'response_body_tab.dart';
import 'response_cookies_tab.dart';
import 'response_headers_tab.dart';
import 'response_timeline_tab.dart';

/// The full response viewer: a Copy / curl action row, a status line
/// (`200 · 124 ms · 512 B`), then a Body | Headers | Cookies | Timeline tab
/// set. `Copy` takes the raw body; `curl` builds a curl command for the
/// request currently in the builder with the active environment resolved.
class ResponsePanel extends ConsumerWidget {
  const ResponsePanel({super.key, required this.sendState});

  final SendState sendState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final response = sendState.response;

    final actions = Row(
      children: [
        const Spacer(),
        HeaderGhostButton(
          key: const Key('copy-body-button'),
          label: 'Copy',
          onPressed: () {
            if (response == null || response.error != null) {
              showToast(ref, 'Nothing to copy');
              return;
            }
            Clipboard.setData(ClipboardData(text: rawResponseBody(response.body)));
            showToast(ref, 'Response copied');
          },
        ),
        const SizedBox(width: AppSpacing.sm),
        HeaderGhostButton(
          key: const Key('copy-curl-button'),
          label: 'curl',
          onPressed: () {
            final variables = ref.read(environmentsProvider).value?.active?.resolvedVariables ?? const {};
            Clipboard.setData(ClipboardData(text: buildCurl(ref.read(requestDraftProvider), variables: variables)));
            showToast(ref, 'curl copied');
          },
        ),
      ],
    );

    if (response == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          actions,
          const SizedBox(height: AppSpacing.lg),
          Text('No response yet', style: AppTypography.codeLg),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Pick a request and send. Cmd/Ctrl + Enter also sends.',
            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      );
    }
    if (response.error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          actions,
          Expanded(
            child: Center(
              key: const Key('response-error'),
              child: Text('Error: ${response.error}'),
            ),
          ),
        ],
      );
    }

    final dot = Text('·', style: AppTypography.codeMd.copyWith(color: AppColors.outline));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        actions,
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            StatusBadge(statusCode: response.status ?? 0),
            const SizedBox(width: AppSpacing.sm),
            dot,
            const SizedBox(width: AppSpacing.sm),
            Text('${response.elapsedMs} ms', key: const Key('response-elapsed'), style: AppTypography.codeMd),
            const SizedBox(width: AppSpacing.sm),
            dot,
            const SizedBox(width: AppSpacing.sm),
            Text('${response.sizeBytes} B', key: const Key('response-size'), style: AppTypography.codeMd),
          ],
        ),
        Expanded(
          child: DefaultTabController(
            length: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: 'Body'),
                    Tab(text: 'Headers'),
                    Tab(text: 'Cookies'),
                    Tab(text: 'Timeline'),
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
