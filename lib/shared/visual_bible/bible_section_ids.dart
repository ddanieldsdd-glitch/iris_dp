import 'package:flutter/material.dart';

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
  static const settings = 'settings';

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
        settings => 'Configuración',
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
        settings => Icons.settings_outlined,
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
