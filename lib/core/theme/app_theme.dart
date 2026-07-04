import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_radius.dart';

class AppTheme {
  AppTheme._();

  static ThemeData _build(AppPalette palette, Brightness brightness) => ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: palette.background,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: palette.accent,
      onPrimary: Colors.white,
      secondary: palette.accent,
      onSecondary: Colors.white,
      error: palette.error,
      onError: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
    ),
    extensions: [palette],
    dividerColor: palette.divider,
    splashColor: palette.accentMuted,
    highlightColor: palette.borderBright,
    cardTheme: CardThemeData(
      color: palette.surfaceElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surfaceOverlay.withValues(alpha: 0.6),
      border: OutlineInputBorder(
        borderRadius: AppRadius.medium,
        borderSide: BorderSide(color: palette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.medium,
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.medium,
        borderSide: BorderSide(color: palette.accent, width: 1.5),
      ),
      hintStyle: AppTypography.bodyMedium(palette),
    ),
    textTheme: AppTypography.textTheme(palette),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surfaceOverlay,
      contentTextStyle: AppTypography.snackBar(palette),
      behavior: SnackBarBehavior.floating,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.medium,
        side: BorderSide(color: palette.borderBright),
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
  );

  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);
  static ThemeData get light => _build(AppPalette.light, Brightness.light);
}
