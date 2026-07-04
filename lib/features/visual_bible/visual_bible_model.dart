import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';

/// Categorías del moodboard.
abstract final class MoodboardCategory {
  static const lighting = 'lighting';
  static const color = 'color';
  static const framing = 'framing';
  static const texture = 'texture';
  static const location = 'location';
  static const character = 'character';
  static const reference = 'reference';

  static String label(String? key) => switch (key) {
        lighting => 'Luz',
        color => 'Color',
        framing => 'Encuadre',
        texture => 'Textura',
        location => 'Localización',
        character => 'Personaje',
        reference => 'Referencia',
        _ => 'Sin categoría',
      };

  static const all = [
    lighting,
    color,
    framing,
    texture,
    location,
    character,
    reference,
  ];
}

abstract final class MoodboardSource {
  static const manual = 'manual';
  static const aiGenerated = 'ai_generated';
  static const scouting = 'scouting';
  static const artemisCapture = 'artemis_capture';
  static const unrealRender = 'unreal_render';
  static const scriptReference = 'script_reference';

  static String badge(String source) => switch (source) {
        aiGenerated => 'IA',
        scouting => 'Scout',
        unrealRender => 'UE5',
        artemisCapture => 'Artemis',
        scriptReference => 'Guion',
        _ => '',
      };
}

abstract final class VisualBibleModuleType {
  static const visualBible = 'visual_bible';
  static const lookBible = 'look_bible';

  static String label(String type) => switch (type) {
        visualBible => 'Biblia Visual',
        lookBible => 'Look Bible',
        _ => 'Documento',
      };
}

/// Departamentos para PDF de una página.
abstract final class VisualBibleDepartment {
  static const gaffer = 'gaffer';
  static const colorist = 'colorist';
  static const cameraOp = 'camera_op';
  static const productionDesign = 'production_design';

  static String label(String id) => switch (id) {
        gaffer => 'Gaffer',
        colorist => 'Colorista',
        cameraOp => 'Operador de cámara',
        productionDesign => 'Dirección de arte',
        _ => id,
      };

  static const all = [gaffer, colorist, cameraOp, productionDesign];
}

class VisualBibleData {
  int id;
  final int projectId;
  String? visualConcept;
  List<Map<String, String>> narrativeReferences;
  String? lightingPhilosophy;
  String? lightQuality;
  String? contrastStyle;
  String? keyFillRatioDay;
  String? keyFillRatioNight;
  String? lightSource;
  String? cameraPhilosophy;
  String? movementStyle;
  List<String> preferredMovements;
  String? lensPhilosophy;
  String? opticType;
  List<int> primaryFocalLengths;
  int? primaryLensId;
  String? aspectRatio;
  String? aspectRatioJustification;
  String? imageTexture;
  String? grainLevel;
  String? highlightBehavior;
  String? shadowBehavior;
  String? workingLutName;
  String? creativeLutName;
  String? creativeLutDescription;

  VisualBibleData({
    this.id = 0,
    required this.projectId,
    this.visualConcept,
    List<Map<String, String>>? narrativeReferences,
    this.lightingPhilosophy,
    this.lightQuality,
    this.contrastStyle,
    this.keyFillRatioDay,
    this.keyFillRatioNight,
    this.lightSource,
    this.cameraPhilosophy,
    this.movementStyle,
    List<String>? preferredMovements,
    this.lensPhilosophy,
    this.opticType,
    List<int>? primaryFocalLengths,
    this.primaryLensId,
    this.aspectRatio,
    this.aspectRatioJustification,
    this.imageTexture,
    this.grainLevel,
    this.highlightBehavior,
    this.shadowBehavior,
    this.workingLutName,
    this.creativeLutName,
    this.creativeLutDescription,
  })  : narrativeReferences = narrativeReferences ?? [],
        preferredMovements = preferredMovements ?? [],
        primaryFocalLengths = primaryFocalLengths ?? [];

  factory VisualBibleData.fromRow(VisualBible row) {
    return VisualBibleData(
      id: row.id,
      projectId: row.projectId,
      visualConcept: row.visualConcept,
      narrativeReferences: _decodeRefList(row.narrativeReferences),
      lightingPhilosophy: row.lightingPhilosophy,
      lightQuality: row.lightQuality,
      contrastStyle: row.contrastStyle,
      keyFillRatioDay: row.keyFillRatioDay,
      keyFillRatioNight: row.keyFillRatioNight,
      lightSource: row.lightSource,
      cameraPhilosophy: row.cameraPhilosophy,
      movementStyle: row.movementStyle,
      preferredMovements: _decodeStringList(row.preferredMovements),
      lensPhilosophy: row.lensPhilosophy,
      opticType: row.opticType,
      primaryFocalLengths: _decodeIntList(row.primaryFocalLengths),
      primaryLensId: row.primaryLensId,
      aspectRatio: row.aspectRatio,
      aspectRatioJustification: row.aspectRatioJustification,
      imageTexture: row.imageTexture,
      grainLevel: row.grainLevel,
      highlightBehavior: row.highlightBehavior,
      shadowBehavior: row.shadowBehavior,
      workingLutName: row.workingLutName,
      creativeLutName: row.creativeLutName,
      creativeLutDescription: row.creativeLutDescription,
    );
  }

  VisualBiblesCompanion toCompanion() {
    return VisualBiblesCompanion(
      id: id > 0 ? Value(id) : const Value.absent(),
      projectId: Value(projectId),
      visualConcept: Value(visualConcept),
      narrativeReferences: Value(_encodeRefList(narrativeReferences)),
      lightingPhilosophy: Value(lightingPhilosophy),
      lightQuality: Value(lightQuality),
      contrastStyle: Value(contrastStyle),
      keyFillRatioDay: Value(keyFillRatioDay),
      keyFillRatioNight: Value(keyFillRatioNight),
      lightSource: Value(lightSource),
      cameraPhilosophy: Value(cameraPhilosophy),
      movementStyle: Value(movementStyle),
      preferredMovements: Value(_encodeStringList(preferredMovements)),
      lensPhilosophy: Value(lensPhilosophy),
      opticType: Value(opticType),
      primaryFocalLengths: Value(_encodeIntList(primaryFocalLengths)),
      primaryLensId: Value(primaryLensId),
      aspectRatio: Value(aspectRatio),
      aspectRatioJustification: Value(aspectRatioJustification),
      imageTexture: Value(imageTexture),
      grainLevel: Value(grainLevel),
      highlightBehavior: Value(highlightBehavior),
      shadowBehavior: Value(shadowBehavior),
      workingLutName: Value(workingLutName),
      creativeLutName: Value(creativeLutName),
      creativeLutDescription: Value(creativeLutDescription),
      updatedAt: Value(DateTime.now()),
    );
  }

  static List<String> _decodeStringList(String? json) {
    if (json == null || json.trim().isEmpty) return [];
    try {
      return (jsonDecode(json) as List<dynamic>).map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  static String? _encodeStringList(List<String> items) =>
      items.isEmpty ? null : jsonEncode(items);

  static List<int> _decodeIntList(String? json) {
    if (json == null || json.trim().isEmpty) return [];
    try {
      return (jsonDecode(json) as List<dynamic>)
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((n) => n > 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String? _encodeIntList(List<int> items) =>
      items.isEmpty ? null : jsonEncode(items);

  static List<Map<String, String>> _decodeRefList(String? json) {
    if (json == null || json.trim().isEmpty) return [];
    try {
      final raw = jsonDecode(json) as List<dynamic>;
      return raw.map((e) {
        if (e is Map) {
          return e.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
        }
        return {'title': e.toString()};
      }).toList();
    } catch (_) {
      return _decodeStringList(json).map((s) => {'title': s}).toList();
    }
  }

  static String? _encodeRefList(List<Map<String, String>> items) {
    if (items.isEmpty) return null;
    return jsonEncode(items);
  }
}

class ColorBlockModel {
  final int id;
  final int bibleId;
  String blockName;
  String? emotionalIntent;
  List<String> dominantColors;
  List<String> accentColors;
  List<String> prohibitedColors;
  int? colorTempKelvin;
  int sortOrder;

  ColorBlockModel({
    required this.id,
    required this.bibleId,
    required this.blockName,
    this.emotionalIntent,
    List<String>? dominantColors,
    List<String>? accentColors,
    List<String>? prohibitedColors,
    this.colorTempKelvin,
    this.sortOrder = 0,
  })  : dominantColors = dominantColors ?? [],
        accentColors = accentColors ?? [],
        prohibitedColors = prohibitedColors ?? [];

  factory ColorBlockModel.fromRow(VisualBibleColorBlock row) {
    return ColorBlockModel(
      id: row.id,
      bibleId: row.bibleId,
      blockName: row.blockName,
      emotionalIntent: row.emotionalIntent,
      dominantColors: VisualBibleData._decodeStringList(row.dominantColors),
      accentColors: VisualBibleData._decodeStringList(row.accentColors),
      prohibitedColors: VisualBibleData._decodeStringList(row.prohibitedColors),
      colorTempKelvin: row.colorTempKelvin,
      sortOrder: row.sortOrder,
    );
  }

  VisualBibleColorBlocksCompanion toCompanion() {
    return VisualBibleColorBlocksCompanion(
      id: Value(id),
      bibleId: Value(bibleId),
      blockName: Value(blockName),
      emotionalIntent: Value(emotionalIntent),
      dominantColors: Value(jsonEncode(dominantColors)),
      accentColors: Value(
        accentColors.isEmpty ? null : jsonEncode(accentColors),
      ),
      prohibitedColors: Value(
        prohibitedColors.isEmpty ? null : jsonEncode(prohibitedColors),
      ),
      colorTempKelvin: Value(colorTempKelvin),
      sortOrder: Value(sortOrder),
    );
  }

  List<Color> get swatches => dominantColors
      .map((hex) {
        final clean = hex.replaceAll('#', '');
        final value = int.tryParse(clean, radix: 16);
        if (value == null) return null;
        return Color(0xFF000000 | value);
      })
      .whereType<Color>()
      .toList();
}

class LocationRefModel {
  final int id;
  final int bibleId;
  final String locationName;
  String? lightingNote;
  String? colorNote;
  List<String> referenceImages;
  List<int> linkedShotIds;

  LocationRefModel({
    required this.id,
    required this.bibleId,
    required this.locationName,
    this.lightingNote,
    this.colorNote,
    List<String>? referenceImages,
    List<int>? linkedShotIds,
  })  : referenceImages = referenceImages ?? [],
        linkedShotIds = linkedShotIds ?? [];

  factory LocationRefModel.fromRow(VisualBibleLocationRef row) {
    return LocationRefModel(
      id: row.id,
      bibleId: row.bibleId,
      locationName: row.locationName,
      lightingNote: row.lightingNote,
      colorNote: row.colorNote,
      referenceImages: VisualBibleData._decodeStringList(row.referenceImages),
      linkedShotIds: VisualBibleData._decodeIntList(row.linkedShotIds),
    );
  }

  VisualBibleLocationRefsCompanion toCompanion() {
    return VisualBibleLocationRefsCompanion(
      id: id > 0 ? Value(id) : const Value.absent(),
      bibleId: Value(bibleId),
      locationName: Value(locationName),
      lightingNote: Value(lightingNote),
      colorNote: Value(colorNote),
      referenceImages: Value(
        referenceImages.isEmpty ? null : jsonEncode(referenceImages),
      ),
      linkedShotIds: Value(
        linkedShotIds.isEmpty ? null : jsonEncode(linkedShotIds),
      ),
    );
  }
}

class MoodboardImageModel {
  final int id;
  final int projectId;
  final int? bibleId;
  final String imagePath;
  final String source;
  String? category;
  String? caption;
  String? filmReference;
  int? linkedSceneId;
  String? linkedLocationName;
  int sortOrder;

  MoodboardImageModel({
    required this.id,
    required this.projectId,
    this.bibleId,
    required this.imagePath,
    required this.source,
    this.category,
    this.caption,
    this.filmReference,
    this.linkedSceneId,
    this.linkedLocationName,
    this.sortOrder = 0,
  });

  factory MoodboardImageModel.fromRow(MoodboardImage row) {
    return MoodboardImageModel(
      id: row.id,
      projectId: row.projectId,
      bibleId: row.bibleId,
      imagePath: row.imagePath,
      source: row.source,
      category: row.category,
      caption: row.caption,
      filmReference: row.filmReference,
      linkedSceneId: row.linkedSceneId,
      linkedLocationName: row.linkedLocationName,
      sortOrder: row.sortOrder,
    );
  }

  MoodboardImagesCompanion toCompanion() {
    return MoodboardImagesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      bibleId: Value(bibleId),
      imagePath: Value(imagePath),
      source: Value(source),
      category: Value(category),
      caption: Value(caption),
      filmReference: Value(filmReference),
      linkedSceneId: Value(linkedSceneId),
      linkedLocationName: Value(linkedLocationName),
      sortOrder: Value(sortOrder),
    );
  }
}
