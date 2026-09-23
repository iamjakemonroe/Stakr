import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Wraps a screen body in the light lavender base color plus a few soft,
/// low-opacity color washes for depth — nowhere near strong enough to
/// affect text contrast (that was the actual bug in the earlier dark/glow
/// version: bright blobs sitting directly behind text). Pure gradients,
/// no blur filter, cheap regardless of what's on top.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.background),
        Positioned(top: -80, right: -60, child: _wash(AppColors.accent, 220)),
        Positioned(bottom: -100, left: -80, child: _wash(AppColors.mint, 240)),
        child,
      ],
    );
  }

  Widget _wash(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.10),
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}
