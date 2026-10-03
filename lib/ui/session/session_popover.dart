import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../environments/environments_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The session popover, drawn over the app by [SessionButton] under the
/// header's right edge: a click outside or `Esc` closes it ([onClose]).
class SessionPopover extends ConsumerWidget {
  const SessionPopover({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environmentName = ref.watch(environmentsProvider).value?.active?.name ?? 'No environment';

    return Stack(
      children: [
        // Everything outside the panel: swallow the click and close.
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onClose),
        ),
        Positioned(
          top: 58,
          right: AppSpacing.lg + 2,
          child: Focus(
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                onClose();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                key: const Key('session-popover'),
                width: 420,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.dialog),
                  border: Border.all(color: AppColors.outlineVariant),
                  boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 40, offset: Offset(0, 18))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Session · $environmentName', style: AppTypography.headlineSm),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
