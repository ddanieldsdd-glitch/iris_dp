import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../technical_script_settings.dart';

/// Colores de fila que se pueden elegir; el valor es el que se guarda en
/// `Shots.notesHighlight`.
const kScriptRowColors = ['green', 'yellow', 'red', 'blue', 'cream', 'pink'];

String scriptRowColorLabel(String value) => switch (value) {
  'green' => 'Verde',
  'yellow' => 'Amarillo',
  'red' => 'Rojo',
  'blue' => 'Azul',
  'cream' => 'Crema',
  'pink' => 'Rosa',
  _ => value,
};

/// Aspecto de la tabla del guion técnico: en hoja (papel blanco, como el
/// Word y el PDF) u oscura (los colores de la app).
@immutable
class ScriptSheetTheme {
  final bool isSheet;
  final Color paper;
  final Color ink;
  final Color hint;
  final Color line;
  final double lineWidth;
  final Color tile;
  final Color tileBorder;
  final Color accent;
  final String fontFamily;
  final double fontSize;

  const ScriptSheetTheme._({
    required this.isSheet,
    required this.paper,
    required this.ink,
    required this.hint,
    required this.line,
    required this.lineWidth,
    required this.tile,
    required this.tileBorder,
    required this.accent,
    required this.fontFamily,
    required this.fontSize,
  });

  factory ScriptSheetTheme.resolve(
    TechnicalScriptSettings settings,
    AppPalette palette,
  ) {
    final sheet = settings.view == ScriptView.sheet;
    return ScriptSheetTheme._(
      isSheet: sheet,
      paper: sheet ? const Color(0xFFFFFFFF) : palette.background,
      ink: sheet ? const Color(0xFF111111) : palette.textPrimary,
      hint: sheet ? const Color(0xFFB0B0B0) : palette.textTertiary,
      line: sheet ? const Color(0xFF000000) : palette.border,
      lineWidth: sheet ? 1 : 0.6,
      tile: sheet
          ? const Color(0xFFF2F2F2)
          : palette.surfaceOverlay.withValues(alpha: 0.4),
      tileBorder: sheet ? const Color(0xFFCFCFCF) : palette.divider,
      accent: palette.accent,
      fontFamily: settings.fontFamily,
      fontSize: settings.fontSize,
    );
  }

  BorderSide get side => BorderSide(color: line, width: lineWidth);

  TextStyle _font(TextStyle style) {
    try {
      return GoogleFonts.getFont(fontFamily, textStyle: style);
    } catch (_) {
      return style;
    }
  }

  TextStyle get text =>
      _font(TextStyle(fontSize: fontSize, height: 1.35, color: ink));

  TextStyle get hintText => text.copyWith(color: hint);

  TextStyle get headerText => _font(
    TextStyle(
      fontSize: (fontSize - 1.5).clamp(9, 16).toDouble(),
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: ink,
    ),
  );

  /// Fondo de la fila de títulos: el color de la escena, aclarado en hoja y
  /// apagado en oscuro, para que el texto se lea.
  Color headerFill(Color sceneColor) => isSheet
      ? Color.lerp(sceneColor, const Color(0xFFFFFFFF), 0.68)!
      : Color.lerp(sceneColor, paper, 0.62)!;

  /// Fondo de un plano marcado con color.
  Color? rowFill(String? value) {
    final base = switch (value) {
      'green' => const Color(0xFF6AA84F),
      'yellow' => const Color(0xFFF1C232),
      'red' => const Color(0xFFE06666),
      'blue' => const Color(0xFF6FA8DC),
      'cream' => const Color(0xFFF6B26B),
      'pink' => const Color(0xFFD5A6BD),
      _ => null,
    };
    if (base == null) return null;
    return Color.lerp(base, paper, isSheet ? 0.72 : 0.74);
  }

  @override
  bool operator ==(Object other) =>
      other is ScriptSheetTheme &&
      other.isSheet == isSheet &&
      other.paper == paper &&
      other.ink == ink &&
      other.line == line &&
      other.accent == accent &&
      other.fontFamily == fontFamily &&
      other.fontSize == fontSize;

  @override
  int get hashCode =>
      Object.hash(isSheet, paper, ink, line, accent, fontFamily, fontSize);
}

/// Pone el aspecto de la tabla al alcance de sus celdas.
class ScriptSheet extends InheritedWidget {
  final ScriptSheetTheme theme;

  const ScriptSheet({super.key, required this.theme, required super.child});

  static ScriptSheetTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScriptSheet>()!.theme;

  @override
  bool updateShouldNotify(ScriptSheet oldWidget) => oldWidget.theme != theme;
}
