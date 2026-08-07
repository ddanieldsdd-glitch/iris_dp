import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';

/// Valores predefinidos de estilo de contraste.
const kContrastStyles = [
  'Alto contraste',
  'Bajo contraste',
  'Flat',
  'Natural',
  'Noir',
];

/// Tipos de documento para integración GoodNotes / PDF anotado.
abstract final class GoodNotesModuleType {
  static const guionTecnico = 'guion_tecnico';
  static const plantaCamara = 'planta_camara';
  static const ordenRodaje = 'orden_rodaje';
  static const shootDocument = 'shoot_document';
  static const lookBible = 'look_bible';
  static const visualBible = 'visual_bible';
  static const storyboard = 'storyboard';

  static String label(String type) => switch (type) {
        guionTecnico => 'Guion técnico',
        plantaCamara => 'Planta de cámara',
        ordenRodaje => 'Documentos para el rodaje',
        shootDocument => 'Documento de rodaje',
        lookBible => 'Look Bible',
        visualBible => 'Biblia Visual',
        storyboard => 'Storyboard',
        _ => 'Documento',
      };
}

/// Modelo editable del Look Bible (mapeo desde [LookBible] Drift).
class LookBibleData {
  int id;
  final int projectId;
  String? visualConcept;
  List<String> colorHexPalette;
  String? lutName;
  List<String> filmReferences;
  String? lightingPhilosophy;
  String? contrastStyle;
  String? actOneNotes;
  String? actTwoNotes;
  String? actThreeNotes;
  List<String> moodboardImagePaths;

  LookBibleData({
    this.id = 0,
    required this.projectId,
    this.visualConcept,
    List<String>? colorHexPalette,
    this.lutName,
    List<String>? filmReferences,
    this.lightingPhilosophy,
    this.contrastStyle,
    this.actOneNotes,
    this.actTwoNotes,
    this.actThreeNotes,
    List<String>? moodboardImagePaths,
  })  : colorHexPalette = colorHexPalette ?? [],
        filmReferences = filmReferences ?? [],
        moodboardImagePaths = moodboardImagePaths ?? [];

  factory LookBibleData.empty(int projectId) =>
      LookBibleData(projectId: projectId);

  factory LookBibleData.fromRow(LookBible row) {
    return LookBibleData(
      id: row.id,
      projectId: row.projectId,
      visualConcept: row.visualConcept,
      colorHexPalette: _decodeStringList(row.colorPalette),
      lutName: row.lutName,
      filmReferences: _decodeStringList(row.filmReferences),
      lightingPhilosophy: row.lightingPhilosophy,
      contrastStyle: row.contrastStyle,
      actOneNotes: row.actOneNotes,
      actTwoNotes: row.actTwoNotes,
      actThreeNotes: row.actThreeNotes,
      moodboardImagePaths: _decodeStringList(row.moodboardImages),
    );
  }

  LookBiblesCompanion toCompanion() {
    return LookBiblesCompanion(
      id: id > 0 ? Value(id) : const Value.absent(),
      projectId: Value(projectId),
      visualConcept: Value(visualConcept),
      colorPalette: Value(_encodeStringList(colorHexPalette)),
      lutName: Value(lutName),
      filmReferences: Value(_encodeStringList(filmReferences)),
      lightingPhilosophy: Value(lightingPhilosophy),
      contrastStyle: Value(contrastStyle),
      actOneNotes: Value(actOneNotes),
      actTwoNotes: Value(actTwoNotes),
      actThreeNotes: Value(actThreeNotes),
      moodboardImages: Value(_encodeStringList(moodboardImagePaths)),
      updatedAt: Value(DateTime.now()),
    );
  }

  List<Color> get paletteColors => colorHexPalette
      .map((hex) {
        final clean = hex.replaceAll('#', '');
        final value = int.tryParse(clean, radix: 16);
        if (value == null) return null;
        return Color(0xFF000000 | value);
      })
      .whereType<Color>()
      .toList();

  static List<String> _decodeStringList(String? json) {
    if (json == null || json.trim().isEmpty) return [];
    try {
      final raw = jsonDecode(json) as List<dynamic>;
      return raw.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  static String? _encodeStringList(List<String> items) {
    if (items.isEmpty) return null;
    return jsonEncode(items);
  }
}
