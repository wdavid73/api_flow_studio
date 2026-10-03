import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../collections/sidebar_tree.dart';
import '../request_builder/request_bar.dart';
import '../request_builder/send_provider.dart';
import '../response_viewer/response_panel.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'workspace_shortcuts.dart';

/// Window width below which the response moves under the request instead of
/// sitting beside it.
const double workspaceStackBreakpoint = 1100;

const double _sidebarWidth = 300;

/// The Workspace destination: sidebar | request | response, like the
/// playground's three panels. Below [workspaceStackBreakpoint] the sidebar
/// stays on the left and the request and response stack in a column.
class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WorkspaceShortcuts(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < workspaceStackBreakpoint;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: _sidebarWidth, child: SidebarTree()),
              const VerticalDivider(width: 1),
              Expanded(
                child: stacked
                    ? const Column(
                        children: [
                          Expanded(child: _RequestPane()),
                          Divider(height: 1),
                          Expanded(child: _ResponsePane()),
                        ],
                      )
                    : const Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 100, child: _RequestPane()),
                          VerticalDivider(width: 1),
                          Expanded(flex: 92, child: _ResponsePane()),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RequestPane extends StatelessWidget {
  const _RequestPane();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: Key('workspace-request-pane'), child: RequestBar());
}

class _ResponsePane extends ConsumerWidget {
  const _ResponsePane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A Material, not a colored DecoratedBox: rows inside (history tiles)
    // paint their ink on the nearest Material and a DecoratedBox would hide it.
    return Material(
      key: const Key('workspace-response-pane'),
      color: AppColors.responseBackground,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl - 4),
        child: ResponsePanel(sendState: ref.watch(sendStateProvider)),
      ),
    );
  }
}
