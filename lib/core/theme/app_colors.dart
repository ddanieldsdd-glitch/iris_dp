import 'package:flutter/material.dart';

/// Paleta semántica de la app. Se inyecta vía [ThemeExtension] en cada tema.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceOverlay;
  final Color ambientBlue;
  final Color ambientIndigo;
  final Color ambientWarm;
  final Color accent;
  final Color accentMuted;
  final Color focusGlow;
  final Color accentGlow;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color success;
  final Color warning;
  final Color error;
  final Color divider;
  final Color border;
  final Color borderBright;
  final Color highlightGreen;
  final Color highlightYellow;
  final Color highlightRed;
  final Color glassHighlight;
  final Color glassShadow;
  final Color chipShadow;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceOverlay,
    required this.ambientBlue,
    required this.ambientIndigo,
    required this.ambientWarm,
    required this.accent,
    required this.accentMuted,
    required this.focusGlow,
    required this.accentGlow,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.warning,
    required this.error,
    required this.divider,
    required this.border,
    required this.borderBright,
    required this.highlightGreen,
    required this.highlightYellow,
    required this.highlightRed,
    required this.glassHighlight,
    required this.glassShadow,
    required this.chipShadow,
  });

  static const dark = AppPalette(
    background: Color(0xFF000000),
    surface: Color(0xFF0D0D0D),
    surfaceElevated: Color(0xFF1A1A1C),
    surfaceOverlay: Color(0xFF2C2C2E),
    ambientBlue: Color(0xFF0A1628),
    ambientIndigo: Color(0xFF14102A),
    ambientWarm: Color(0xFF1A1008),
    accent: Color(0xFF2997FF),
    accentMuted: Color(0x402997FF),
    focusGlow: Color(0x4DFFFFFF),
    accentGlow: Color(0x662997FF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0x99EBEBF5),
    textTertiary: Color(0xFF636366),
    success: Color(0xFF30D158),
    warning: Color(0xFFFFD60A),
    error: Color(0xFFFF453A),
    divider: Color(0xFF2C2C2E),
    border: Color(0x33FFFFFF),
    borderBright: Color(0x1AFFFFFF),
    highlightGreen: Color(0x4030D158),
    highlightYellow: Color(0x40FFD60A),
    highlightRed: Color(0x40FF453A),
    glassHighlight: Color(0x1FFFFFFF),
    glassShadow: Color(0x00000000),
    chipShadow: Color(0x66000000),
  );

  static const light = AppPalette(
    background: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceOverlay: Color(0xFFE5E5EA),
    ambientBlue: Color(0xFFD6E8FF),
    ambientIndigo: Color(0xFFE8DEFF),
    ambientWarm: Color(0xFFFFEDD5),
    accent: Color(0xFF007AFF),
    accentMuted: Color(0x40007AFF),
    focusGlow: Color(0x33000000),
    accentGlow: Color(0x4D007AFF),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0x993C3C43),
    textTertiary: Color(0xFF8E8E93),
    success: Color(0xFF34C759),
    warning: Color(0xFFFFCC00),
    error: Color(0xFFFF3B30),
    divider: Color(0xFFC6C6C8),
    border: Color(0x33000000),
    borderBright: Color(0x1A000000),
    highlightGreen: Color(0x4034C759),
    highlightYellow: Color(0x40FFCC00),
    highlightRed: Color(0x40FF3B30),
    glassHighlight: Color(0xBFFFFFFF),
    glassShadow: Color(0x1A000000),
    chipShadow: Color(0x26000000),
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceOverlay,
    Color? ambientBlue,
    Color? ambientIndigo,
    Color? ambientWarm,
    Color? accent,
    Color? accentMuted,
    Color? focusGlow,
    Color? accentGlow,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? success,
    Color? warning,
    Color? error,
    Color? divider,
    Color? border,
    Color? borderBright,
    Color? highlightGreen,
    Color? highlightYellow,
    Color? highlightRed,
    Color? glassHighlight,
    Color? glassShadow,
    Color? chipShadow,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceOverlay: surfaceOverlay ?? this.surfaceOverlay,
      ambientBlue: ambientBlue ?? this.ambientBlue,
      ambientIndigo: ambientIndigo ?? this.ambientIndigo,
      ambientWarm: ambientWarm ?? this.ambientWarm,
      accent: accent ?? this.accent,
      accentMuted: accentMuted ?? this.accentMuted,
      focusGlow: focusGlow ?? this.focusGlow,
      accentGlow: accentGlow ?? this.accentGlow,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      divider: divider ?? this.divider,
      border: border ?? this.border,
      borderBright: borderBright ?? this.borderBright,
      highlightGreen: highlightGreen ?? this.highlightGreen,
      highlightYellow: highlightYellow ?? this.highlightYellow,
      highlightRed: highlightRed ?? this.highlightRed,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      glassShadow: glassShadow ?? this.glassShadow,
      chipShadow: chipShadow ?? this.chipShadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceOverlay: Color.lerp(surfaceOverlay, other.surfaceOverlay, t)!,
      ambientBlue: Color.lerp(ambientBlue, other.ambientBlue, t)!,
      ambientIndigo: Color.lerp(ambientIndigo, other.ambientIndigo, t)!,
      ambientWarm: Color.lerp(ambientWarm, other.ambientWarm, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      focusGlow: Color.lerp(focusGlow, other.focusGlow, t)!,
      accentGlow: Color.lerp(accentGlow, other.accentGlow, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderBright: Color.lerp(borderBright, other.borderBright, t)!,
      highlightGreen: Color.lerp(highlightGreen, other.highlightGreen, t)!,
      highlightYellow: Color.lerp(highlightYellow, other.highlightYellow, t)!,
      highlightRed: Color.lerp(highlightRed, other.highlightRed, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
      chipShadow: Color.lerp(chipShadow, other.chipShadow, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.dark;
}
