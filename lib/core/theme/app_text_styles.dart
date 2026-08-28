import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Centralized text styles. [display] uses a distinct display font to give
/// headings/balances more visual weight than the default body font.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle display({
    double fontSize = 32,
    FontWeight fontWeight = FontWeight.w800,
    Color color = AppColors.textPrimary,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );

  static TextStyle body({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.textPrimary,
  }) => GoogleFonts.inter(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}
