import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The shell backdrop: the surface color with a faint lime glow in the top
/// left corner (the radial gradient on the playground body).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        gradient: RadialGradient(
          center: Alignment(-0.8, -1.2),
          radius: 0.9,
          colors: [AppColors.backgroundGlow, Color(0x00D6FF4A)],
        ),
      ),
      child: child,
    );
  }
}
