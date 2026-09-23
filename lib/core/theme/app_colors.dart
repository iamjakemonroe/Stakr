import 'package:flutter/material.dart';

/// Bright, playful palette for the "fun mobile game" visual direction —
/// light background, bold saturated colors, high-contrast dark text.
/// Replaced an earlier dark/glass direction that tested poorly (glow
/// blobs washed out text; blur on a light background reads muddy rather
/// than "cool glass"). Kept neutral/global — no region-specific imagery.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF6F3FF); // soft lavender-white
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);

  static const Color accent = Color(0xFF7C4DFF); // vivid violet
  static const Color accentSecondary = Color(
    0xFFFFB300,
  ); // warm gold, for coins

  // Extra bright accents for variety across cards/mascot/illustrations —
  // a "fun game" palette needs more than two colors or every screen looks
  // the same.
  static const Color mint = Color(0xFF00C2A8);
  static const Color coral = Color(0xFFFF6B6B);
  static const Color sky = Color(0xFF3DA9FC);

  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFFF5A5F);

  // Dark warm indigo-black rather than pure black — softer, matches the
  // violet brand color, still comfortably high-contrast on the light bg.
  static const Color textPrimary = Color(0xFF241C3B);
  static const Color textSecondary = Color(0xFF6E6482);

  // ── "3D sticker" card tokens ─────────────────────────────────────────
  // Used by PopCard: a solid-color card with a bold outline and an offset
  // drop-shadow in a darker shade of the same hue underneath it — the
  // Duolingo/Candy Crush "pressable button" look. No blur/transparency
  // anywhere, so contrast never depends on what happens to be behind it.
  static const Color cardOutline = Color(0xFF241C3B);

  /// Darkens [color] for the offset "3D depth" shadow beneath a card or
  /// button — same hue, not a generic gray/black, so the depth shadow
  /// reads as part of the object instead of a separate drop shadow.
  static Color depthShade(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - 0.16).clamp(0.0, 1.0)).toColor();
  }
}
