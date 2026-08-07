import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';

/// Categorías del moodboard (DP).
abstract final class MoodboardCategory {
  static const lighting = 'lighting';
  static const color = 'color';
  static const framing = 'framing';
  static const texture = 'texture';
  static const location = 'location';
  static const optics = 'optics';
  static const cameraTest = 'camera_test';
  static const reference = 'reference';

  static String label(String? key) => switch (key) {
        lighting => 'Luz',
        color => 'Color',
        framing => 'Encuadre',
        texture => 'Textura',
        location => 'Localización',
        optics => 'Óptica/Lente',
        cameraTest => 'Prueba de cámara',
        reference => 'Referencia',
        _ => 'Sin categoría',
      };

  static const all = [
    lighting,
    color,
    framing,
    texture,
    location,
    optics,
    cameraTest,
    reference,
  ];
}

abstract final class MoodboardSource {
  static const manual = 'manual';
  static const scouting = 'scouting';
  static const artemisCapture = 'artemis_capture';
  static const unrealRender = 'unreal_render';
  static const scriptReference = 'script_reference';

  static String badge(String source) => switch (source) {
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
        visualBible => 'Biblia de Fotografía',
        lookBible => 'Look Bible',
        _ => 'Documento',
      };
}

/// Modos de export PDF.
abstract final class VisualBibleExportMode {
  static const pitch = 'pitch';
  static const techScout = 'tech_scout';
  static const full = 'full';

  static String label(String id) => switch (id) {
        pitch => 'Pitch deck',
        techScout => 'Tech scout',
        full => 'Documento completo',
        _ => id,
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

/// Secciones de la biblia de fotografía.
abstract final class BibleSectionId {
  static const direction = 'direction';
  static const concept = 'concept';
  static const camera = 'camera';
  static const optics = 'optics';
  static const exposure = 'exposure';
  static const lighting = 'lighting';
  static const colorImage = 'color_image';
  static const format = 'format';
  static const texture = 'texture';
  static const location = 'location';
  static const cameraTests = 'camera_tests';
  static const workflow = 'workflow';
  static const moodboard = 'moodboard';

  static const all = [
    direction,
    concept,
    camera,
    optics,
    exposure,
    lighting,
    colorImage,
    format,
    texture,
    location,
    cameraTests,
    workflow,
    moodboard,
  ];

  static String label(String id) => switch (id) {
        direction => 'Dirección',
        concept => 'Concepto de imagen',
        camera => 'Cámara y sensor',
        optics => 'Óptica',
        exposure => 'Exposición',
        lighting => 'Iluminación',
        colorImage => 'Color e imagen',
        format => 'Aspect ratio',
        texture => 'Textura',
        location => 'Localización',
        cameraTests => 'Pruebas de cámara',
        workflow => 'Workflow',
        moodboard => 'Moodboard',
        _ => id,
      };

  static IconData icon(String id) => switch (id) {
        direction => Icons.theater_comedy_outlined,
        concept => Icons.auto_stories_outlined,
        camera => Icons.videocam_outlined,
        optics => Icons.camera_outlined,
        exposure => Icons.exposure_outlined,
        lighting => Icons.wb_sunny_outlined,
        colorImage => Icons.palette_outlined,
        format => Icons.aspect_ratio_outlined,
        texture => Icons.grain_outlined,
        location => Icons.location_on_outlined,
        cameraTests => Icons.science_outlined,
        workflow => Icons.account_tree_outlined,
        moodboard => Icons.photo_library_outlined,
        _ => Icons.article_outlined,
      };

  static String? moodboardCategory(String id) => switch (id) {
        lighting => MoodboardCategory.lighting,
        colorImage => MoodboardCategory.color,
        optics => MoodboardCategory.optics,
        texture => MoodboardCategory.texture,
        location => MoodboardCategory.location,
        cameraTests => MoodboardCategory.cameraTest,
        exposure => MoodboardCategory.lighting,
        _ => null,
      };
}

class VisualBibleData {
  int id;
  final int projectId;
  String? visualConcept;
  String? tone;
  String? creativeIntention;
  String? stagingApproach;
  String? pointOfView;
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

  int? primaryCameraId;
  String? recordingFormat;
  String? codec;
  String? resolutionNotes;
  String? frameRateNotes;
  int? nativeIso;
  String? defaultTStop;
  String? ndNotes;
  String? deliveryColorSpace;
  String? captureResolution;
  String? deliveryResolution;
  String? workflowPipeline;
  String? diffusionNotes;
  String? sensorShadowBehavior;
  String? colorScienceNotes;
  String? lowLightNotes;
  String? opticCharacterNotes;
  String? filtrationNotes;
  String? depthOfFieldNotes;
  List<Map<String, String>> cameraMovements;
  List<Map<String, String>> actVisualNotes;

  String? conceptNarrativeIntent;
  String? directionNarrativeIntent;
  String? cameraNarrativeIntent;
  String? opticsNarrativeIntent;
  String? exposureNarrativeIntent;
  String? lightingNarrativeIntent;
  String? colorNarrativeIntent;
  String? formatNarrativeIntent;
  String? textureNarrativeIntent;
  String? opticsConfigJson;

  VisualBibleData({
    this.id = 0,
    required this.projectId,
    this.visualConcept,
    this.tone,
    this.creativeIntention,
    this.stagingApproach,
    this.pointOfView,
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
    this.primaryCameraId,
    this.recordingFormat,
    this.codec,
    this.resolutionNotes,
    this.frameRateNotes,
    this.nativeIso,
    this.defaultTStop,
    this.ndNotes,
    this.deliveryColorSpace,
    this.captureResolution,
    this.deliveryResolution,
    this.workflowPipeline,
    this.diffusionNotes,
    this.sensorShadowBehavior,
    this.colorScienceNotes,
    this.lowLightNotes,
    this.opticCharacterNotes,
    this.filtrationNotes,
    this.depthOfFieldNotes,
    List<Map<String, String>>? cameraMovements,
    List<Map<String, String>>? actVisualNotes,
    this.conceptNarrativeIntent,
    this.directionNarrativeIntent,
    this.cameraNarrativeIntent,
    this.opticsNarrativeIntent,
    this.exposureNarrativeIntent,
    this.lightingNarrativeIntent,
    this.colorNarrativeIntent,
    this.formatNarrativeIntent,
    this.textureNarrativeIntent,
    this.opticsConfigJson,
  })  : narrativeReferences = narrativeReferences ?? [],
        preferredMovements = preferredMovements ?? [],
        primaryFocalLengths = primaryFocalLengths ?? [],
        cameraMovements = cameraMovements ?? [],
        actVisualNotes = actVisualNotes ?? [];

  factory VisualBibleData.fromRow(VisualBible row) {
    return VisualBibleData(
      id: row.id,
      projectId: row.projectId,
      visualConcept: row.visualConcept,
      tone: row.tone,
      creativeIntention: row.creativeIntention,
      stagingApproach: row.stagingApproach,
      pointOfView: row.pointOfView,
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
      primaryCameraId: row.primaryCameraId,
      recordingFormat: row.recordingFormat,
      codec: row.codec,
      resolutionNotes: row.resolutionNotes,
      frameRateNotes: row.frameRateNotes,
      nativeIso: row.nativeIso,
      defaultTStop: row.defaultTStop,
      ndNotes: row.ndNotes,
      deliveryColorSpace: row.deliveryColorSpace,
      captureResolution: row.captureResolution,
      deliveryResolution: row.deliveryResolution,
      workflowPipeline: row.workflowPipeline,
      diffusionNotes: row.diffusionNotes,
      sensorShadowBehavior: row.sensorShadowBehavior,
      colorScienceNotes: row.colorScienceNotes,
      lowLightNotes: row.lowLightNotes,
      opticCharacterNotes: row.opticCharacterNotes,
      filtrationNotes: row.filtrationNotes,
      depthOfFieldNotes: row.depthOfFieldNotes,
      cameraMovements: _decodeRefList(row.cameraMovementsJson),
      actVisualNotes: _decodeRefList(row.actVisualNotes),
      conceptNarrativeIntent: row.conceptNarrativeIntent,
      directionNarrativeIntent: row.directionNarrativeIntent,
      cameraNarrativeIntent: row.cameraNarrativeIntent,
      opticsNarrativeIntent: row.opticsNarrativeIntent,
      exposureNarrativeIntent: row.exposureNarrativeIntent,
      lightingNarrativeIntent: row.lightingNarrativeIntent,
      colorNarrativeIntent: row.colorNarrativeIntent,
      formatNarrativeIntent: row.formatNarrativeIntent,
      textureNarrativeIntent: row.textureNarrativeIntent,
      opticsConfigJson: row.opticsConfigJson,
    );
  }

  VisualBiblesCompanion toCompanion() {
    return VisualBiblesCompanion(
      id: id > 0 ? Value(id) : const Value.absent(),
      projectId: Value(projectId),
      visualConcept: Value(visualConcept),
      tone: Value(tone),
      creativeIntention: Value(creativeIntention),
      stagingApproach: Value(stagingApproach),
      pointOfView: Value(pointOfView),
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
      primaryCameraId: Value(primaryCameraId),
      recordingFormat: Value(recordingFormat),
      codec: Value(codec),
      resolutionNotes: Value(resolutionNotes),
      frameRateNotes: Value(frameRateNotes),
      nativeIso: Value(nativeIso),
      defaultTStop: Value(defaultTStop),
      ndNotes: Value(ndNotes),
      deliveryColorSpace: Value(deliveryColorSpace),
      captureResolution: Value(captureResolution),
      deliveryResolution: Value(deliveryResolution),
      workflowPipeline: Value(workflowPipeline),
      diffusionNotes: Value(diffusionNotes),
      sensorShadowBehavior: Value(sensorShadowBehavior),
      colorScienceNotes: Value(colorScienceNotes),
      lowLightNotes: Value(lowLightNotes),
      opticCharacterNotes: Value(opticCharacterNotes),
      filtrationNotes: Value(filtrationNotes),
      depthOfFieldNotes: Value(depthOfFieldNotes),
      cameraMovementsJson: Value(_encodeRefList(cameraMovements)),
      actVisualNotes: Value(_encodeRefList(actVisualNotes)),
      conceptNarrativeIntent: Value(conceptNarrativeIntent),
      directionNarrativeIntent: Value(directionNarrativeIntent),
      cameraNarrativeIntent: Value(cameraNarrativeIntent),
      opticsNarrativeIntent: Value(opticsNarrativeIntent),
      exposureNarrativeIntent: Value(exposureNarrativeIntent),
      lightingNarrativeIntent: Value(lightingNarrativeIntent),
      colorNarrativeIntent: Value(colorNarrativeIntent),
      formatNarrativeIntent: Value(formatNarrativeIntent),
      textureNarrativeIntent: Value(textureNarrativeIntent),
      opticsConfigJson: Value(opticsConfigJson),
      updatedAt: Value(DateTime.now()),
    );
  }

  String? narrativeIntentForSection(String sectionId) => switch (sectionId) {
        BibleSectionId.direction => directionNarrativeIntent,
        BibleSectionId.concept => conceptNarrativeIntent,
        BibleSectionId.camera => cameraNarrativeIntent,
        BibleSectionId.optics => opticsNarrativeIntent,
        BibleSectionId.exposure => exposureNarrativeIntent,
        BibleSectionId.lighting => lightingNarrativeIntent,
        BibleSectionId.colorImage => colorNarrativeIntent,
        BibleSectionId.format => formatNarrativeIntent,
        BibleSectionId.texture => textureNarrativeIntent,
        _ => null,
      };

  void setNarrativeIntentForSection(String sectionId, String? value) {
    switch (sectionId) {
      case BibleSectionId.direction:
        directionNarrativeIntent = value;
      case BibleSectionId.concept:
        conceptNarrativeIntent = value;
      case BibleSectionId.camera:
        cameraNarrativeIntent = value;
      case BibleSectionId.optics:
        opticsNarrativeIntent = value;
      case BibleSectionId.exposure:
        exposureNarrativeIntent = value;
      case BibleSectionId.lighting:
        lightingNarrativeIntent = value;
      case BibleSectionId.colorImage:
        colorNarrativeIntent = value;
      case BibleSectionId.format:
        formatNarrativeIntent = value;
      case BibleSectionId.texture:
        textureNarrativeIntent = value;
    }
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

  Map<String, dynamic> toSnapshotJson() => {
        'visualConcept': visualConcept,
        'narrativeReferences': narrativeReferences,
        'workingLutName': workingLutName,
        'creativeLutName': creativeLutName,
        'aspectRatio': aspectRatio,
        'primaryCameraId': primaryCameraId,
        'primaryLensId': primaryLensId,
        'defaultTStop': defaultTStop,
        'deliveryColorSpace': deliveryColorSpace,
      };
}

class ColorBlockModel {
  final int id;
  final int bibleId;
  String blockName;
  String? emotionalIntent;
  List<String> dominantColors;
  List<String> accentColors;
  List<String> prohibitedColors;
  List<String> referenceImages;
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
    List<String>? referenceImages,
    this.colorTempKelvin,
    this.sortOrder = 0,
  })  : dominantColors = dominantColors ?? [],
        accentColors = accentColors ?? [],
        prohibitedColors = prohibitedColors ?? [],
        referenceImages = referenceImages ?? [];

  factory ColorBlockModel.fromRow(VisualBibleColorBlock row) {
    return ColorBlockModel(
      id: row.id,
      bibleId: row.bibleId,
      blockName: row.blockName,
      emotionalIntent: row.emotionalIntent,
      dominantColors: VisualBibleData._decodeStringList(row.dominantColors),
      accentColors: VisualBibleData._decodeStringList(row.accentColors),
      prohibitedColors: VisualBibleData._decodeStringList(row.prohibitedColors),
      referenceImages: VisualBibleData._decodeStringList(row.referenceImages),
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
      referenceImages: Value(
        referenceImages.isEmpty ? null : jsonEncode(referenceImages),
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

class ExposureBlockModel {
  final int id;
  final int bibleId;
  String blockName;
  String? highlightStrategy;
  String? shadowStrategy;
  String? keyFillRatio;
  String? narrativeIntent;
  List<String> referenceImages;
  int sortOrder;

  ExposureBlockModel({
    required this.id,
    required this.bibleId,
    required this.blockName,
    this.highlightStrategy,
    this.shadowStrategy,
    this.keyFillRatio,
    this.narrativeIntent,
    List<String>? referenceImages,
    this.sortOrder = 0,
  }) : referenceImages = referenceImages ?? [];

  factory ExposureBlockModel.fromRow(ExposureBlock row) {
    return ExposureBlockModel(
      id: row.id,
      bibleId: row.bibleId,
      blockName: row.blockName,
      highlightStrategy: row.highlightStrategy,
      shadowStrategy: row.shadowStrategy,
      keyFillRatio: row.keyFillRatio,
      narrativeIntent: row.narrativeIntent,
      referenceImages: VisualBibleData._decodeStringList(row.referenceImages),
      sortOrder: row.sortOrder,
    );
  }

  ExposureBlocksCompanion toCompanion() {
    return ExposureBlocksCompanion(
      id: id > 0 ? Value(id) : const Value.absent(),
      bibleId: Value(bibleId),
      blockName: Value(blockName),
      highlightStrategy: Value(highlightStrategy),
      shadowStrategy: Value(shadowStrategy),
      keyFillRatio: Value(keyFillRatio),
      narrativeIntent: Value(narrativeIntent),
      referenceImages: Value(
        referenceImages.isEmpty ? null : jsonEncode(referenceImages),
      ),
      sortOrder: Value(sortOrder),
    );
  }
}

class LightingSetupModel {
  final int id;
  final int bibleId;
  String setupName;
  String? narrativeNote;
  String diagramJson;
  String? gelNotes;
  String? practicalMotivation;
  String? referenceImagePath;
  int sortOrder;

  LightingSetupModel({
    required this.id,
    required this.bibleId,
    required this.setupName,
    this.narrativeNote,
    this.diagramJson = '[]',
    this.gelNotes,
    this.practicalMotivation,
    this.referenceImagePath,
    this.sortOrder = 0,
  });

  factory LightingSetupModel.fromRow(LightingSetup row) {
    return LightingSetupModel(
      id: row.id,
      bibleId: row.bibleId,
      setupName: row.setupName,
      narrativeNote: row.narrativeNote,
      diagramJson: row.diagramJson,
      gelNotes: row.gelNotes,
      practicalMotivation: row.practicalMotivation,
      referenceImagePath: row.referenceImagePath,
      sortOrder: row.sortOrder,
    );
  }

  LightingSetupsCompanion toCompanion() {
    return LightingSetupsCompanion(
      id: id > 0 ? Value(id) : const Value.absent(),
      bibleId: Value(bibleId),
      setupName: Value(setupName),
      narrativeNote: Value(narrativeNote),
      diagramJson: Value(diagramJson),
      gelNotes: Value(gelNotes),
      practicalMotivation: Value(practicalMotivation),
      referenceImagePath: Value(referenceImagePath),
      sortOrder: Value(sortOrder),
    );
  }
}

class CameraTestModel {
  final int id;
  final int bibleId;
  String testName;
  int? cameraId;
  int? lensId;
  String? lutName;
  String? lightCondition;
  String? notes;
  List<String> imagePaths;
  DateTime? testedAt;
  int sortOrder;

  CameraTestModel({
    required this.id,
    required this.bibleId,
    required this.testName,
    this.cameraId,
    this.lensId,
    this.lutName,
    this.lightCondition,
    this.notes,
    List<String>? imagePaths,
    this.testedAt,
    this.sortOrder = 0,
  }) : imagePaths = imagePaths ?? [];

  factory CameraTestModel.fromRow(CameraTest row) {
    return CameraTestModel(
      id: row.id,
      bibleId: row.bibleId,
      testName: row.testName,
      cameraId: row.cameraId,
      lensId: row.lensId,
      lutName: row.lutName,
      lightCondition: row.lightCondition,
      notes: row.notes,
      imagePaths: VisualBibleData._decodeStringList(row.imagePaths),
      testedAt: row.testedAt,
      sortOrder: row.sortOrder,
    );
  }

  CameraTestsCompanion toCompanion() {
    return CameraTestsCompanion(
      id: id > 0 ? Value(id) : const Value.absent(),
      bibleId: Value(bibleId),
      testName: Value(testName),
      cameraId: Value(cameraId),
      lensId: Value(lensId),
      lutName: Value(lutName),
      lightCondition: Value(lightCondition),
      notes: Value(notes),
      imagePaths: Value(jsonEncode(imagePaths)),
      testedAt: Value(testedAt),
      sortOrder: Value(sortOrder),
    );
  }
}

class WorkflowStepModel {
  String step;
  String? responsible;
  String? notes;
  String? lutReference;

  WorkflowStepModel({
    required this.step,
    this.responsible,
    this.notes,
    this.lutReference,
  });

  factory WorkflowStepModel.fromJson(Map<String, dynamic> json) {
    return WorkflowStepModel(
      step: json['step']?.toString() ?? '',
      responsible: json['responsible']?.toString(),
      notes: json['notes']?.toString(),
      lutReference: json['lutReference']?.toString(),
    );
  }

  Map<String, String> toJson() => {
        'step': step,
        if (responsible != null) 'responsible': responsible!,
        if (notes != null) 'notes': notes!,
        if (lutReference != null) 'lutReference': lutReference!,
      };

  static List<WorkflowStepModel> decode(String? json) {
    if (json == null || json.trim().isEmpty) return defaultPipeline();
    try {
      final raw = jsonDecode(json) as List<dynamic>;
      return raw
          .map((e) => WorkflowStepModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return defaultPipeline();
    }
  }

  static String encode(List<WorkflowStepModel> steps) => jsonEncode(
        steps.map((s) => s.toJson()).toList(),
      );

  static List<WorkflowStepModel> defaultPipeline() => [
        WorkflowStepModel(step: 'Cámara / Sensor'),
        WorkflowStepModel(step: 'Tarjetas / Backup'),
        WorkflowStepModel(step: 'Dailies'),
        WorkflowStepModel(step: 'Color / Grading'),
        WorkflowStepModel(step: 'Entrega'),
      ];
}

class LocationRefModel {
  final int id;
  final int bibleId;
  final String locationName;
  int? locationSiteId;
  int? locationBasePlanId;
  String? lightingNote;
  String? colorNote;
  String? stagingNote;
  List<String> referenceImages;
  List<int> linkedShotIds;
  String? solarOrientation;
  String? availableLightHours;
  String? existingPracticals;
  int? estimatedColorTempKelvin;

  LocationRefModel({
    required this.id,
    required this.bibleId,
    required this.locationName,
    this.locationSiteId,
    this.locationBasePlanId,
    this.lightingNote,
    this.colorNote,
    this.stagingNote,
    List<String>? referenceImages,
    List<int>? linkedShotIds,
    this.solarOrientation,
    this.availableLightHours,
    this.existingPracticals,
    this.estimatedColorTempKelvin,
  })  : referenceImages = referenceImages ?? [],
        linkedShotIds = linkedShotIds ?? [];

  factory LocationRefModel.fromRow(VisualBibleLocationRef row) {
    return LocationRefModel(
      id: row.id,
      bibleId: row.bibleId,
      locationName: row.locationName,
      locationSiteId: row.locationSiteId,
      locationBasePlanId: row.locationBasePlanId,
      lightingNote: row.lightingNote,
      colorNote: row.colorNote,
      stagingNote: row.stagingNote,
      referenceImages: VisualBibleData._decodeStringList(row.referenceImages),
      linkedShotIds: VisualBibleData._decodeIntList(row.linkedShotIds),
      solarOrientation: row.solarOrientation,
      availableLightHours: row.availableLightHours,
      existingPracticals: row.existingPracticals,
      estimatedColorTempKelvin: row.estimatedColorTempKelvin,
    );
  }

  VisualBibleLocationRefsCompanion toCompanion() {
    return VisualBibleLocationRefsCompanion(
      id: id > 0 ? Value(id) : const Value.absent(),
      bibleId: Value(bibleId),
      locationName: Value(locationName),
      locationSiteId: Value(locationSiteId),
      locationBasePlanId: Value(locationBasePlanId),
      lightingNote: Value(lightingNote),
      colorNote: Value(colorNote),
      stagingNote: Value(stagingNote),
      referenceImages: Value(
        referenceImages.isEmpty ? null : jsonEncode(referenceImages),
      ),
      linkedShotIds: Value(
        linkedShotIds.isEmpty ? null : jsonEncode(linkedShotIds),
      ),
      solarOrientation: Value(solarOrientation),
      availableLightHours: Value(availableLightHours),
      existingPracticals: Value(existingPracticals),
      estimatedColorTempKelvin: Value(estimatedColorTempKelvin),
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
  int? linkedLocationBasePlanId;
  int? groupId;
  List<String> assignedSections;
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
    this.linkedLocationBasePlanId,
    this.groupId,
    List<String>? assignedSections,
    this.sortOrder = 0,
  }) : assignedSections = assignedSections ?? [];

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
      linkedLocationBasePlanId: row.linkedLocationBasePlanId,
      groupId: row.groupId,
      assignedSections: VisualBibleData._decodeStringList(row.assignedSections),
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
      linkedLocationBasePlanId: Value(linkedLocationBasePlanId),
      groupId: Value(groupId),
      assignedSections: Value(
        assignedSections.isEmpty
            ? null
            : VisualBibleData._encodeStringList(assignedSections),
      ),
      sortOrder: Value(sortOrder),
    );
  }
}

class BibleCommentModel {
  final int id;
  final int bibleId;
  final String authorRole;
  final String targetType;
  final int? targetId;
  final String comment;
  final DateTime createdAt;

  BibleCommentModel({
    required this.id,
    required this.bibleId,
    required this.authorRole,
    required this.targetType,
    this.targetId,
    required this.comment,
    required this.createdAt,
  });

  factory BibleCommentModel.fromRow(BibleComment row) {
    return BibleCommentModel(
      id: row.id,
      bibleId: row.bibleId,
      authorRole: row.authorRole,
      targetType: row.targetType,
      targetId: row.targetId,
      comment: row.comment,
      createdAt: row.createdAt,
    );
  }
}
