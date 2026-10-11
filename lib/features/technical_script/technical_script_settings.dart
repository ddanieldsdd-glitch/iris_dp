import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cómo se pinta la tabla del guion técnico.
enum ScriptView { sheet, dark }

/// Columnas que se pueden ocultar.
abstract final class ScriptColumn {
  static const fStop = 'f';
  static const personajes = 'pers';
  static const duracion = 'dur';
  static const planta = 'planta';
  static const storyboard = 'story';

  static const optional = [fStop, personajes, duracion, planta, storyboard];

  static String label(String column) => switch (column) {
    fStop => 'F',
    personajes => 'Personajes',
    duracion => 'Duración',
    planta => 'Planta',
    storyboard => 'Storyboard',
    _ => column,
  };
}

/// Qué enseña la casilla Planta: la planta dibujada del plano, sus bocetos
/// o las dos cosas.
enum ScriptPlanView {
  both('Planta y boceto'),
  plan('Solo planta'),
  sketch('Solo boceto');

  final String label;
  const ScriptPlanView(this.label);

  bool get showsPlan => this != sketch;
  bool get showsSketch => this != plan;

  static ScriptPlanView? parse(Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }

  /// Clave, dentro de `Shots.cellStylesJson`, de la excepción de un plano.
  static const shotKey = '_planView';

  /// Lo que vale para un plano: su excepción o, si no tiene, [general].
  static ScriptPlanView of(String? cellStylesJson, ScriptPlanView general) {
    if (cellStylesJson == null || cellStylesJson.isEmpty) return general;
    try {
      final decoded = jsonDecode(cellStylesJson);
      return (decoded is Map ? parse(decoded[shotKey]) : null) ?? general;
    } catch (_) {
      return general;
    }
  }
}

/// Fuentes de la tabla. La clave es el nombre en Google Fonts.
const kScriptFonts = {
  'Inter': 'Inter',
  'Noto Sans': 'Noto Sans',
  'Tinos': 'Con remates',
};

/// Ajustes del guion técnico. De momento son los mismos para todos los
/// proyectos; todo pasa por [technicalScriptSettingsProvider] para poder
/// guardarlos por proyecto más adelante sin tocar la pantalla.
class TechnicalScriptSettings {
  final ScriptView view;
  final Set<String> hiddenColumns;
  final List<String> customMovements;
  final List<String> customAngles;
  final String fontFamily;
  final double fontSize;
  final ScriptPlanView planView;

  const TechnicalScriptSettings({
    this.view = ScriptView.sheet,
    this.hiddenColumns = const {ScriptColumn.duracion, ScriptColumn.storyboard},
    this.customMovements = const [],
    this.customAngles = const [],
    this.fontFamily = 'Inter',
    this.fontSize = 13,
    this.planView = ScriptPlanView.both,
  });

  static const minFontSize = 10.0;
  static const maxFontSize = 20.0;

  bool shows(String column) => !hiddenColumns.contains(column);

  TechnicalScriptSettings copyWith({
    ScriptView? view,
    Set<String>? hiddenColumns,
    List<String>? customMovements,
    List<String>? customAngles,
    String? fontFamily,
    double? fontSize,
    ScriptPlanView? planView,
  }) => TechnicalScriptSettings(
    view: view ?? this.view,
    hiddenColumns: hiddenColumns ?? this.hiddenColumns,
    customMovements: customMovements ?? this.customMovements,
    customAngles: customAngles ?? this.customAngles,
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    planView: planView ?? this.planView,
  );

  Map<String, dynamic> toJson() => {
    'view': view.name,
    'hiddenColumns': hiddenColumns.toList(),
    'storyboardSeen': true,
    'customMovements': customMovements,
    'customAngles': customAngles,
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'planView': planView.name,
  };

  factory TechnicalScriptSettings.fromJson(Map<String, dynamic> json) {
    const d = TechnicalScriptSettings();
    List<String> strings(Object? v) => [
      if (v is List)
        for (final e in v)
          if (e is String && e.trim().isNotEmpty) e.trim(),
    ];
    final font = json['fontFamily'];
    final size = json['fontSize'];
    return TechnicalScriptSettings(
      view: json['view'] == ScriptView.dark.name
          ? ScriptView.dark
          : ScriptView.sheet,
      hiddenColumns: json['hiddenColumns'] is List
          ? {
              ...strings(json['hiddenColumns']),
              // Guardado antes de existir la columna de storyboard: nace
              // oculta, como en una instalación nueva.
              if (json['storyboardSeen'] != true) ScriptColumn.storyboard,
            }
          : d.hiddenColumns,
      customMovements: strings(json['customMovements']),
      customAngles: strings(json['customAngles']),
      fontFamily: font is String && kScriptFonts.containsKey(font)
          ? font
          : d.fontFamily,
      fontSize: size is num
          ? size.toDouble().clamp(minFontSize, maxFontSize)
          : d.fontSize,
      planView: ScriptPlanView.parse(json['planView']) ?? d.planView,
    );
  }
}

class TechnicalScriptSettingsNotifier
    extends StateNotifier<TechnicalScriptSettings> {
  TechnicalScriptSettingsNotifier() : super(const TechnicalScriptSettings()) {
    _load();
  }

  static const _key = 'iris_technical_script_settings';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || !mounted) return;
      state = TechnicalScriptSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      // Sin ajustes guardados o ilegibles: valen los de partida.
    }
  }

  Future<void> update(
    TechnicalScriptSettings Function(TechnicalScriptSettings) change,
  ) async {
    state = change(state);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(state.toJson()));
    } catch (_) {
      // El cambio vale para esta sesión aunque no se pueda guardar.
    }
  }

  Future<void> toggleColumn(String column) => update((s) {
    final hidden = {...s.hiddenColumns};
    hidden.contains(column) ? hidden.remove(column) : hidden.add(column);
    return s.copyWith(hiddenColumns: hidden);
  });

  /// Añade un movimiento propio; devuelve el nombre tal como queda.
  Future<String?> addMovement(String name, List<String> builtIn) =>
      _addOption(name, builtIn, movement: true);

  Future<String?> addAngle(String name, List<String> builtIn) =>
      _addOption(name, builtIn, movement: false);

  Future<String?> _addOption(
    String name,
    List<String> builtIn, {
    required bool movement,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) return null;
    final current = movement ? state.customMovements : state.customAngles;
    for (final o in [...builtIn, ...current]) {
      if (o.toLowerCase() == clean.toLowerCase()) return o;
    }
    await update(
      (s) => movement
          ? s.copyWith(customMovements: [...current, clean])
          : s.copyWith(customAngles: [...current, clean]),
    );
    return clean;
  }

  Future<void> removeMovement(String name) => update(
    (s) => s.copyWith(customMovements: [...s.customMovements]..remove(name)),
  );

  Future<void> removeAngle(String name) => update(
    (s) => s.copyWith(customAngles: [...s.customAngles]..remove(name)),
  );
}

final technicalScriptSettingsProvider =
    StateNotifierProvider<
      TechnicalScriptSettingsNotifier,
      TechnicalScriptSettings
    >((ref) => TechnicalScriptSettingsNotifier());
