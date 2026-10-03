import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'session_clock.dart';
import 'session_label.dart';
import 'session_popover.dart';
import 'session_provider.dart';

export 'session_clock.dart' show sessionClockProvider;

/// The header's session button: the time left on the access token (or `No
/// token`) over `Authorization: Bearer`. Pressing it opens the session
/// popover. The label refreshes every 30 seconds so an expiring token turns to
/// `Token expired` on its own.
class SessionButton extends ConsumerStatefulWidget {
  const SessionButton({super.key});

  @override
  ConsumerState<SessionButton> createState() => _SessionButtonState();
}

class _SessionButtonState extends ConsumerState<SessionButton> {
  final OverlayPortalController _popover = OverlayPortalController();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final label = sessionLabel(session, ref.watch(sessionClockProvider)());

    final topColor = switch (label.tone) {
      SessionTone.none => AppColors.onSurface,
      SessionTone.valid => AppColors.tertiary,
      SessionTone.expired => AppColors.warning,
    };

    return OverlayPortal(
      controller: _popover,
      overlayChildBuilder: (context) => SessionPopover(onClose: _popover.hide),
      child: InkWell(
        key: const Key('session-button'),
        onTap: _popover.toggle,
        borderRadius: BorderRadius.circular(AppRadius.field),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg - 2, vertical: AppSpacing.sm - 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.field),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.top,
                style: AppTypography.bodyMd.copyWith(color: topColor, fontWeight: FontWeight.w600),
              ),
              Text(label.bottom, style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
            ],
          ),
        ),
      ),
    );
  }
}
