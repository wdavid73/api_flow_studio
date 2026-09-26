import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../request_builder/send_provider.dart';
import '../theme/app_spacing.dart';
import '../theme/widgets/status_badge.dart';
import 'response_body_tab.dart';
import 'response_cookies_tab.dart';
import 'response_headers_tab.dart';
import 'response_timeline_tab.dart';

/// The full response viewer: status/latency/size, then a
/// Body | Headers | Cookies | Timeline tab set.
class ResponsePanel extends StatelessWidget {
  const ResponsePanel({super.key, required this.sendState});

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            StatusBadge(statusCode: response.status ?? 0),
            const SizedBox(width: AppSpacing.md),
            Text('${response.elapsedMs}ms', key: const Key('response-elapsed')),
            const SizedBox(width: AppSpacing.md),
            Text('${response.sizeBytes}B', key: const Key('response-size')),
            const Spacer(),
            IconButton(
              key: const Key('copy-body-button'),
              tooltip: 'Copy body',
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () => Clipboard.setData(
                ClipboardData(text: rawResponseBody(response.body)),
              ),
            ),
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
