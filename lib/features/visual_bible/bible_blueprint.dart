import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/visual_bible/bible_section_ids.dart';

/// Tipo de pieza audiovisual → plantilla base de la biblia.
enum BibleBlueprintType {
  fiction,
  commercial,
  documentary,
}

extension BibleBlueprintTypeX on BibleBlueprintType {
  String get storageKey => name;

  String get label => switch (this) {
        BibleBlueprintType.fiction => 'Ficción',
        BibleBlueprintType.commercial => 'Comercial',
        BibleBlueprintType.documentary => 'Documental',
      };

  String get subtitle => switch (this) {
        BibleBlueprintType.fiction =>
          'Largo / corto. Narrativa, desglose de escenas y mood.',
        BibleBlueprintType.commercial =>
          'Spots / promo. Alto impacto visual y color de marca.',
        BibleBlueprintType.documentary =>
          'Run & gun. Equipo ágil y luz disponible.',
      };

  /// Solo Ficción está operativa; el resto se muestra como próximamente.
  bool get isAvailable => this == BibleBlueprintType.fiction;

  String get availabilityLabel =>
      isAvailable ? label : '$label · Próximamente';

  IconData get icon => switch (this) {
        BibleBlueprintType.fiction => Icons.movie_outlined,
        BibleBlueprintType.commercial => Icons.smart_display_outlined,
        BibleBlueprintType.documentary => Icons.videocam_outlined,
      };

  List<String> get tags => switch (this) {
        BibleBlueprintType.fiction => const ['Scenes', 'Characters'],
        BibleBlueprintType.commercial => const ['Boards', 'Product'],
        BibleBlueprintType.documentary => const ['Interviews', 'B-Roll'],
      };

  /// Secciones ocultas por defecto al aplicar el blueprint.
  Set<String> get defaultHiddenSectionIds => switch (this) {
        BibleBlueprintType.fiction => const {},
        BibleBlueprintType.commercial => {
            BibleSectionId.cameraTests,
            BibleSectionId.workflow,
          },
        BibleBlueprintType.documentary => {
            BibleSectionId.cameraTests,
          },
      };

  static BibleBlueprintType fromStorageKey(String? key) =>
      BibleBlueprintType.values.firstWhere(
        (e) => e.name == key,
        orElse: () => BibleBlueprintType.fiction,
      );
}

/// Estilo visual de una sección (preset Stitch).
enum BibleSectionStyle {
  cinematic,
  technical,
  minimalist,
}

extension BibleSectionStyleX on BibleSectionStyle {
  String get storageKey => name;

  String get label => switch (this) {
        BibleSectionStyle.cinematic => 'Cinematic',
        BibleSectionStyle.technical => 'Technical',
        BibleSectionStyle.minimalist => 'Minimalist',
      };

  /// Solo Cinematic está en desarrollo activo.
  bool get isAvailable => this == BibleSectionStyle.cinematic;

  String get availabilityLabel =>
      isAvailable ? label : '$label · Próximamente';

  Color get dotColor => switch (this) {
        BibleSectionStyle.cinematic => const Color(0xFFC9C2E5),
        BibleSectionStyle.technical => const Color(0xFFBBC7DF),
        BibleSectionStyle.minimalist => const Color(0xFF8A919E),
      };

  /// Valor en columna `template` de BibleSectionDefinitions (salvo freeform).
  String get templateKey => name;

  static BibleSectionStyle fromTemplate(String? template) {
    if (template == null || template == 'standard' || template == 'freeform') {
      return BibleSectionStyle.cinematic;
    }
    return BibleSectionStyle.values.firstWhere(
      (e) => e.name == template,
      orElse: () => BibleSectionStyle.cinematic,
    );
  }

  static bool isLayoutTemplate(String template) =>
      template == 'freeform' ||
      template == 'standard' ||
      BibleSectionStyle.values.any((e) => e.name == template);
}

/// Estilo por defecto según sección + blueprint.
///
/// Plantilla 1 (Ficción): todo cinematic mientras no existan layouts
/// technical / minimalist.
BibleSectionStyle defaultStyleForSection(
  String sectionId,
  BibleBlueprintType blueprint,
) {
  // Comercial / documental: cuando se activen tendrán defaults propios.
  // Hasta entonces Plantilla 1 fuerza cinematic.
  return BibleSectionStyle.cinematic;
}

/// Persistencia local del blueprint por proyecto (sin migración Drift).
abstract final class BibleConfigStore {
  static const _blueprintPrefix = 'iris_bible_blueprint_';
  static const _pdfPresetPrefix = 'iris_bible_pdf_preset_';

  static Future<BibleBlueprintType> loadBlueprint(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    return BibleBlueprintTypeX.fromStorageKey(
      prefs.getString('$_blueprintPrefix$projectId'),
    );
  }

  static Future<void> saveBlueprint(
    int projectId,
    BibleBlueprintType type,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_blueprintPrefix$projectId', type.storageKey);
  }

  static Future<String> loadPdfPreset(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_pdfPresetPrefix$projectId') ?? 'gallery';
  }

  static Future<void> savePdfPreset(int projectId, String preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_pdfPresetPrefix$projectId', preset);
  }
}
