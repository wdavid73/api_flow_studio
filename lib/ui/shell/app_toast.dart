import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// How long a toast stays on screen.
const Duration toastDuration = Duration(milliseconds: 2200);

/// The message currently shown, or null when no toast is visible. Showing a
/// new one replaces it and restarts the [toastDuration] timer.
class ToastNotifier extends Notifier<String?> {
  Timer? _timer;

  @override
  String? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  void show(String message) {
    _timer?.cancel();
    state = message;
    _timer = Timer(toastDuration, () => state = null);
  }
}

final toastProvider = NotifierProvider<ToastNotifier, String?>(ToastNotifier.new);

/// Shows [message] in the app-wide toast, from any screen.
void showToast(WidgetRef ref, String message) => ref.read(toastProvider.notifier).show(message);

/// Draws the toast pill over [child]: bottom center, in the accent color, fading and
/// sliding in over 160ms. It never intercepts pointer events.
class ToastHost extends ConsumerStatefulWidget {
  const ToastHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends ConsumerState<ToastHost> {
  // Kept after the toast hides so the pill can fade out still showing text.
  String _lastMessage = '';

  @override
  Widget build(BuildContext context) {
    final message = ref.watch(toastProvider);
    if (message != null) _lastMessage = message;
    final visible = message != null;

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.xl - 4,
          child: IgnorePointer(
            key: const Key('toast-ignore-pointer'),
            ignoring: true,
            child: Center(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 160),
                offset: visible ? Offset.zero : const Offset(0, 0.6),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: visible ? 1 : 0,
                  child: Container(
                    key: const Key('toast-pill'),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg - 2, vertical: AppSpacing.sm + 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      _lastMessage,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
