import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app's core "3D sticker" surface: a solid-color rounded card with a
/// bold outline and an offset drop-shadow in a darker shade of the same
/// color sitting beneath it, so it reads as one chunky 3D object rather
/// than a flat rectangle with a generic shadow — the Duolingo/Candy Crush
/// "game UI" look. Every card, sheet, and dialog in the app should be
/// built from this instead of a plain [Card]/[Container].
///
/// Replaced an earlier frosted-glass version: blur on a light background
/// read muddy rather than "cool", and made text contrast unpredictable
/// depending on what happened to be behind it. This version never depends
/// on what's behind it — [tint] mixes a soft pastel wash into a white
/// fill rather than a translucent overlay, so dark text stays readable
/// regardless of what's on screen behind the card.
class PopCard extends StatelessWidget {
  const PopCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding,
    this.tint,

    /// Accent border color — used for state highlights (e.g. a gold ring
    /// on "your turn", green on a win, red on check/loss). Null keeps the
    /// default soft neutral outline.
    this.glow,
    this.borderWidth = 2,
    this.depth = 5,

    // Accepted for call-site compatibility with the pre-redesign glass
    // API; blur has no meaning in the flat "sticker card" look, so this
    // is intentionally a no-op. New code shouldn't set it.
    this.blur,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final Color? glow;
  final double borderWidth;
  final double depth;
  final double? blur;

  @override
  Widget build(BuildContext context) {
    final fill = tint == null
        ? Colors.white
        : Color.alphaBlend(tint!.withValues(alpha: 0.14), Colors.white);
    final shadeSource = tint ?? const Color(0xFFE4DEF5);
    final shade = AppColors.depthShade(shadeSource);
    final outlineColor = glow ?? AppColors.cardOutline.withValues(alpha: 0.12);
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      margin: EdgeInsets.only(bottom: depth),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: depth > 0
            ? [BoxShadow(color: shade, offset: Offset(0, depth))]
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: radius,
          border: Border.all(
            color: outlineColor,
            width: glow != null ? borderWidth + 0.5 : borderWidth,
          ),
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
