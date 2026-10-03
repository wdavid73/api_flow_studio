import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The shell backdrop: the surface color with a faint lime glow in the top
/// left corner (the radial gradient on the playground body).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The surface color is its own layer: a BoxDecoration with a gradient
    // ignores its color, so the glow's transparent end would show white.
    return ColoredBox(
      color: AppColors.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -1.2),
            radius: 0.9,
            colors: [AppColors.backgroundGlow, Color(0x00D6FF4A)],
          ),
        ),
        child: child,
      ),
    );
  }
}
