import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../../widgets/bible_sidebar.dart';
import '../theme/bible_theme.dart';
import 'page_layout_recipe.dart';

/// Registro de recetas de layout profesional (identidad Stitch).
abstract final class PageLayoutRecipeRegistry {
  static const directionBento = 'direction_bento_v1';
  static const conceptBento = 'concept_bento_v1';
  static const cameraSpecsHud = 'camera_specs_hud_v1';
  static const lightingAnalysis = 'lighting_analysis_v1';
  static const aspectRatioHud = 'aspect_ratio_hud_v1';
  static const moodboardMasonry = 'moodboard_masonry_v1';
  static const locationHero = 'location_hero_v1';
  static const overviewDashboard = 'overview_dashboard_v1';
  static const freeformGrid = 'freeform_grid_v1';

  static PageLayoutRecipe? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final recipe in all) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  static PageLayoutRecipe? forSectionId(String sectionId) {
    return byId(recipeIdForSection(sectionId));
  }

  static String? recipeIdForSection(String sectionId) {
    return switch (sectionId) {
      BibleSectionId.direction => directionBento,
      BibleSectionId.concept => conceptBento,
      BibleSectionId.camera => cameraSpecsHud,
      BibleSectionId.lighting => lightingAnalysis,
      BibleSectionId.format => aspectRatioHud,
      BibleSectionId.moodboard => moodboardMasonry,
      BibleSectionId.location => locationHero,
      BibleSidebar.overviewSectionId => overviewDashboard,
      _ when sectionId.startsWith('custom_') => freeformGrid,
      _ => null,
    };
  }

  static List<PageLayoutRecipe> get all => [
    _direction,
    _concept,
    _camera,
    _lighting,
    _format,
    _moodboard,
    _location,
    _overview,
    _freeform,
  ];

  static final _direction = PageLayoutRecipe(
    id: directionBento,
    sectionId: BibleSectionId.direction,
    label: 'Dirección · Bento',
    description: 'Hero escena, intención narrativa, tono y referencias.',
    preferredThemeId: BibleThemeIds.cinematic,
    slots: const [
      PageLayoutSlot(
        id: 'scene_header',
        kind: 'hero',
        label: 'Cabecera de escena',
        colSpan: 12,
        rowSpan: 3,
      ),
      PageLayoutSlot(
        id: 'narrative',
        kind: 'narrative',
        label: 'Intención narrativa',
        colSpan: 8,
        rowSpan: 2,
      ),
      PageLayoutSlot(
        id: 'tone',
        kind: 'metrics',
        label: 'Tono y estrategia',
        colSpan: 4,
        rowSpan: 2,
      ),
      PageLayoutSlot(
        id: 'refs',
        kind: 'references',
        label: 'Referencias visuales',
        colSpan: 12,
        rowSpan: 3,
      ),
    ],
  );

  static final _concept = PageLayoutRecipe(
    id: conceptBento,
    sectionId: BibleSectionId.concept,
    label: 'Concepto · Bento',
    description: 'Paleta master, actos, key frame y referencias.',
    preferredThemeId: BibleThemeIds.cinematic,
    slots: const [
      PageLayoutSlot(
        id: 'palette',
        kind: 'color_palette',
        label: 'Paleta master',
        colSpan: 6,
        rowSpan: 2,
      ),
      PageLayoutSlot(
        id: 'metrics',
        kind: 'metrics',
        label: 'Métricas de luz',
        colSpan: 6,
        rowSpan: 2,
      ),
      PageLayoutSlot(
        id: 'acts',
        kind: 'narrative',
        label: 'Actos visuales',
        colSpan: 12,
        rowSpan: 2,
      ),
      PageLayoutSlot(
        id: 'keyframe',
        kind: 'hero',
        label: 'Key frame',
        colSpan: 12,
        rowSpan: 4,
      ),
    ],
  );

  static final _camera = PageLayoutRecipe(
    id: cameraSpecsHud,
    sectionId: BibleSectionId.camera,
    label: 'Cámara · Specs HUD',
    description: 'A-Cam hero, pipeline, movimientos y DIT.',
    preferredThemeId: BibleThemeIds.technical,
    slots: const [
      PageLayoutSlot(
        id: 'acam',
        kind: 'hero',
        label: 'A-Cam hero',
        colSpan: 8,
        rowSpan: 3,
      ),
      PageLayoutSlot(
        id: 'frame_preview',
        kind: 'frame_preview',
        label: 'Frame preview',
        colSpan: 4,
        rowSpan: 3,
      ),
      PageLayoutSlot(
        id: 'specs',
        kind: 'specs_table',
        label: 'Especificaciones',
        colSpan: 12,
        rowSpan: 2,
      ),
    ],
  );

  static final _lighting = PageLayoutRecipe(
    id: lightingAnalysis,
    sectionId: BibleSectionId.lighting,
    label: 'Iluminación · Análisis',
    description: 'Hero con overlay, telemetría Kelvin/ratio y fixtures.',
    preferredThemeId: BibleThemeIds.cinematic,
    slots: const [
      PageLayoutSlot(
        id: 'hero',
        kind: 'hero',
        label: 'Hero de escena',
        colSpan: 12,
        rowSpan: 4,
      ),
      PageLayoutSlot(
        id: 'intent',
        kind: 'narrative',
        label: 'Intención visual',
        colSpan: 8,
        rowSpan: 2,
      ),
      PageLayoutSlot(
        id: 'telemetry',
        kind: 'telemetry',
        label: 'Telemetría',
        colSpan: 4,
        rowSpan: 2,
      ),
      PageLayoutSlot(
        id: 'fixtures',
        kind: 'equipment',
        label: 'Fixtures activos',
        colSpan: 12,
        rowSpan: 2,
      ),
    ],
  );

  static final _format = PageLayoutRecipe(
    id: aspectRatioHud,
    sectionId: BibleSectionId.format,
    label: 'Aspect ratio · HUD',
    description: 'Logic HUD, viewfinder y justificación.',
    preferredThemeId: BibleThemeIds.technical,
    slots: const [
      PageLayoutSlot(
        id: 'logic',
        kind: 'metrics',
        label: 'Logic HUD',
        colSpan: 8,
        rowSpan: 3,
      ),
      PageLayoutSlot(
        id: 'viewfinder',
        kind: 'frame_preview',
        label: 'Viewfinder',
        colSpan: 4,
        rowSpan: 3,
      ),
      PageLayoutSlot(
        id: 'intent',
        kind: 'narrative',
        label: 'Justificación',
        colSpan: 12,
        rowSpan: 2,
      ),
    ],
  );

  static final _moodboard = PageLayoutRecipe(
    id: moodboardMasonry,
    sectionId: BibleSectionId.moodboard,
    label: 'Moodboard · Masonry',
    description: 'Grid editorial con filtros y asignación a pantallas.',
    preferredThemeId: BibleThemeIds.cinematic,
    slots: const [
      PageLayoutSlot(
        id: 'filters',
        kind: 'chips',
        label: 'Filtros',
        colSpan: 12,
        rowSpan: 1,
      ),
      PageLayoutSlot(
        id: 'grid',
        kind: 'masonry',
        label: 'Grid de referencias',
        colSpan: 12,
        rowSpan: 6,
      ),
    ],
  );

  static final _location = PageLayoutRecipe(
    id: locationHero,
    sectionId: BibleSectionId.location,
    label: 'Localización · Hero',
    description: 'Sets, hero, panel solar y atmósfera.',
    preferredThemeId: BibleThemeIds.cinematic,
    slots: const [
      PageLayoutSlot(
        id: 'sets',
        kind: 'chips',
        label: 'Selector de sets',
        colSpan: 12,
        rowSpan: 1,
      ),
      PageLayoutSlot(
        id: 'hero',
        kind: 'hero',
        label: 'Hero de locación',
        colSpan: 8,
        rowSpan: 4,
      ),
      PageLayoutSlot(
        id: 'solar',
        kind: 'telemetry',
        label: 'Panel solar',
        colSpan: 4,
        rowSpan: 4,
      ),
    ],
  );

  static final _overview = PageLayoutRecipe(
    id: overviewDashboard,
    sectionId: BibleSidebar.overviewSectionId,
    label: 'Resumen · Dashboard',
    description: 'Progreso, métricas y siguiente por completar.',
    preferredThemeId: BibleThemeIds.cinematic,
    slots: const [
      PageLayoutSlot(
        id: 'progress',
        kind: 'metrics',
        label: 'Progreso global',
        colSpan: 12,
        rowSpan: 2,
      ),
      PageLayoutSlot(
        id: 'counters',
        kind: 'metrics',
        label: 'Contadores',
        colSpan: 12,
        rowSpan: 2,
      ),
      PageLayoutSlot(
        id: 'next',
        kind: 'list',
        label: 'Siguiente por completar',
        colSpan: 12,
        rowSpan: 3,
      ),
    ],
  );

  static final _freeform = PageLayoutRecipe(
    id: freeformGrid,
    label: 'Libre · Grid 12',
    description: 'Composición modular desde cero.',
    preferredThemeId: BibleThemeIds.cinematic,
    slots: const [
      PageLayoutSlot(
        id: 'main',
        kind: 'dynamic',
        label: 'Contenido',
        colSpan: 12,
        rowSpan: 6,
      ),
    ],
  );
}
