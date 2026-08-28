import 'package:flutter/material.dart';

/// Dark, vibrant palette for the "premium game app" visual direction.
/// Kept neutral/global — no region-specific imagery or color symbolism.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF0E0B1A);
  static const Color surface = Color(0xFF1A1530);
  static const Color surfaceElevated = Color(0xFF241D42);

  static const Color accent = Color(0xFF8B5CF6); // violet
  static const Color accentSecondary = Color(0xFFF5B700); // gold, for coins

  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);

  static const Color textPrimary = Color(0xFFF5F3FF);
  static const Color textSecondary = Color(0xFFA79FC7);
}
