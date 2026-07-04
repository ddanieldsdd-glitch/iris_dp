import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextStyle displayLarge(AppPalette c) => GoogleFonts.inter(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    color: c.textPrimary,
    letterSpacing: -1.2,
    height: 1.05,
  );

  static TextStyle displayMedium(AppPalette c) => GoogleFonts.inter(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: c.textPrimary,
    letterSpacing: -0.8,
    height: 1.1,
  );

  static TextStyle titleLarge(AppPalette c) => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: c.textPrimary,
    letterSpacing: -0.4,
  );

  static TextStyle titleMedium(AppPalette c) => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: c.textPrimary,
    letterSpacing: -0.2,
  );

  static TextStyle bodyLarge(AppPalette c) => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: c.textPrimary,
    letterSpacing: -0.1,
  );

  static TextStyle bodyMedium(AppPalette c) => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: c.textSecondary,
  );

  /// Texto de snackbars y avisos flotantes (alto contraste).
  static TextStyle snackBar(AppPalette c) => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: c.textPrimary,
    height: 1.35,
  );

  static TextStyle caption(AppPalette c) => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: c.textTertiary,
    letterSpacing: 0.3,
  );

  static TextStyle label(AppPalette c) => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: c.textSecondary,
    letterSpacing: 1.2,
  );

  static TextStyle mono(AppPalette c) => GoogleFonts.jetBrainsMono(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: c.textPrimary,
  );

  static TextTheme textTheme(AppPalette c) => TextTheme(
    displayLarge: displayLarge(c),
    displayMedium: displayMedium(c),
    titleLarge: titleLarge(c),
    titleMedium: titleMedium(c),
    bodyLarge: bodyLarge(c),
    bodyMedium: bodyMedium(c),
    labelSmall: caption(c),
  );
}
