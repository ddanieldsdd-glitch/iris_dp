import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/technical_script_export/technical_script_doc.dart';
import 'technical_script_settings.dart';

/// Lo elegido al exportar un guion técnico: formato, índice, columnas,
/// cuerpo de letra y papel. Se guarda en el equipo y se propone la próxima
/// vez; las columnas no dependen de las que se ven en pantalla.
class ScriptExportOptions {
  final bool word;
  final bool index;

  /// Claves de [kScriptDocColumns] que no salen en el documento.
  final Set<String> hiddenColumns;

  /// Cuerpo del texto de la tabla, en puntos.
  final double fontSize;
  final ScriptDocPaper paper;
  final bool landscape;

  const ScriptExportOptions({
    this.word = false,
    this.index = true,
    this.hiddenColumns = const {'dur', 'story'},
    this.fontSize = 8.5,
    this.paper = ScriptDocPaper.a4,
    this.landscape = true,
  });

  /// Columnas que se pueden quitar del documento; ESC, PLANO y ACCIÓN
  /// salen siempre.
  static const optionalColumns = [
    'encuadre',
    'lens',
    'f',
    'pers',
    'dur',
    'ref',
    'story',
    'planta',
    'notes',
  ];

  /// Cuerpos de letra que se ofrecen, con su nombre.
  static final fontSizes = {7.5: 'Pequeña', 8.5: 'Normal', 10.0: 'Grande'};

  /// La primera vez: las columnas que se ven en la hoja del guion técnico.
  factory ScriptExportOptions.fromScreen(TechnicalScriptSettings screen) =>
      ScriptExportOptions(
        hiddenColumns: {
          for (final c in ScriptColumn.optional)
            if (!screen.shows(c)) c,
        },
      );

  bool shows(String column) => !hiddenColumns.contains(column);

  /// El documento con el índice, el papel y la letra elegidos.
  TechnicalScriptDoc applyTo(TechnicalScriptDoc doc) => doc.copyWith(
    includeIndex: index,
    paper: paper,
    landscape: landscape,
    fontSize: fontSize,
  );

  ScriptExportOptions copyWith({
    bool? word,
    bool? index,
    Set<String>? hiddenColumns,
    double? fontSize,
    ScriptDocPaper? paper,
    bool? landscape,
  }) => ScriptExportOptions(
    word: word ?? this.word,
    index: index ?? this.index,
    hiddenColumns: hiddenColumns ?? this.hiddenColumns,
    fontSize: fontSize ?? this.fontSize,
    paper: paper ?? this.paper,
    landscape: landscape ?? this.landscape,
  );

  Map<String, dynamic> toJson() => {
    'word': word,
    'index': index,
    'hiddenColumns': hiddenColumns.toList(),
    'fontSize': fontSize,
    'paper': paper.name,
    'landscape': landscape,
  };

  factory ScriptExportOptions.fromJson(Map<String, dynamic> json) {
    const d = ScriptExportOptions();
    final size = json['fontSize'];
    return ScriptExportOptions(
      word: json['word'] == true,
      index: json['index'] != false,
      hiddenColumns: json['hiddenColumns'] is List
          ? {
              for (final c in json['hiddenColumns'] as List)
                if (c is String && optionalColumns.contains(c)) c,
            }
          : d.hiddenColumns,
      fontSize: size is num && fontSizes.containsKey(size.toDouble())
          ? size.toDouble()
          : d.fontSize,
      paper: ScriptDocPaper.parse(json['paper']) ?? d.paper,
      landscape: json['landscape'] != false,
    );
  }
}

const _prefsKey = 'iris_script_export_options';

/// Lo último que se eligió al exportar; la primera vez, las columnas de la
/// hoja [screen].
Future<ScriptExportOptions> savedScriptExportOptions(
  TechnicalScriptSettings screen,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      return ScriptExportOptions.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    }
  } catch (_) {
    // Ilegible: se parte de la hoja.
  }
  return ScriptExportOptions.fromScreen(screen);
}
