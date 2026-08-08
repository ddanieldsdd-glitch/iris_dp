import '../../bible_block_catalog.dart';
import '../../bible_preset_bundle.dart';
import '../layout/page_layout_recipe_registry.dart';
import '../model/bible_block.dart';
import '../model/bible_block_layout.dart';
import '../model/bible_document.dart';
import '../model/bible_page.dart';
import '../model/bible_page_mode.dart';
import '../theme/bible_theme.dart';
import 'bible_template_package.dart';

/// Plantillas profesionales: estructura Stitch (legacy) + documento V2 con recetas.
abstract final class BibleV2ProfessionalTemplates {
  static List<BibleTemplatePackage> get all => [
    cinematic,
    technical,
    minimalist,
    commercial,
    documentary,
  ];

  static BibleTemplatePackage get cinematic => _professional(
    id: 'v2_prof_cinematic',
    name: 'Cinematic DP Bible',
    description:
        'Dirección, concepto, cámara, iluminación y moodboard con identidad editorial.',
    category: 'Cinematográfica',
    themeId: BibleThemeIds.cinematic,
    legacy: BibleBuiltinPresets.fictionNoir,
    sections: const [
      ('Dirección', 'direction'),
      ('Concepto', 'concept'),
      ('Cámara', 'camera'),
      ('Iluminación', 'lighting'),
      ('Moodboard', 'moodboard'),
    ],
    idealFor: 'Cine / narrativa / ficción',
  );

  static BibleTemplatePackage get technical => _professional(
    id: 'v2_prof_technical',
    name: 'Technical Scout Bible',
    description: 'Specs, telemetría, exposición y workflow de scout técnico.',
    category: 'Técnica',
    themeId: BibleThemeIds.technical,
    legacy: BibleBuiltinPresets.commercialClean,
    sections: const [
      ('Cámara', 'camera'),
      ('Exposición', 'exposure'),
      ('Óptica', 'optics'),
      ('Workflow', 'workflow'),
    ],
    idealFor: 'Producción / publicidad / técnica',
  );

  static BibleTemplatePackage get minimalist => _professional(
    id: 'v2_prof_minimalist',
    name: 'Minimalist Bible',
    description: 'Intención esencial y referencias con mucho aire.',
    category: 'Minimalista',
    themeId: BibleThemeIds.minimalist,
    legacy: BibleBuiltinPresets.documentaryObs,
    sections: const [
      ('Dirección', 'direction'),
      ('Referencias', 'moodboard'),
    ],
    idealFor: 'Documental / observacional',
  );

  static BibleTemplatePackage get commercial => _professional(
    id: 'v2_prof_commercial',
    name: 'Commercial Clean',
    description: 'Concepto, look y color para spots y branded content.',
    category: 'Comercial',
    themeId: BibleThemeIds.minimalist,
    legacy: BibleBuiltinPresets.commercialClean,
    sections: const [
      ('Concepto', 'concept'),
      ('Color', 'color_image'),
      ('Moodboard', 'moodboard'),
    ],
    idealFor: 'Publicidad / producto',
  );

  static BibleTemplatePackage get documentary => _professional(
    id: 'v2_prof_documentary',
    name: 'Documentary Observational',
    description: 'Enfoque narrativo, locaciones y pipeline documental.',
    category: 'Documental',
    themeId: BibleThemeIds.cinematic,
    legacy: BibleBuiltinPresets.documentaryObs,
    sections: const [
      ('Dirección', 'direction'),
      ('Localización', 'location'),
      ('Workflow', 'workflow'),
    ],
    idealFor: 'Documental / no ficción',
  );

  static BibleTemplatePackage? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static BibleTemplatePackage _professional({
    required String id,
    required String name,
    required String description,
    required String category,
    required String themeId,
    required BiblePresetBundle legacy,
    required List<(String label, String sectionId)> sections,
    required String idealFor,
  }) {
    final pages = <BiblePage>[];
    for (var i = 0; i < sections.length; i++) {
      final (label, sectionId) = sections[i];
      final recipeId = PageLayoutRecipeRegistry.recipeIdForSection(sectionId);
      pages.add(
        BiblePage(
          id: 'page_$sectionId',
          groupId: 'main',
          label: label,
          sortOrder: i,
          legacySectionId: sectionId,
          layoutRecipeId: recipeId,
          pageMode: BiblePageMode.recipe,
          blocks: _blocksForSection(sectionId),
        ),
      );
    }

    final doc = BibleDocument(
      projectId: 0,
      themeId: themeId,
      pages: pages,
      exportSettings: {
        'idealFor': idealFor,
        'previewStyle': themeId,
      },
      updatedAt: DateTime.now().toUtc(),
    );

    return BibleTemplatePackage(
      id: id,
      name: name,
      description: description,
      author: 'IRIS DP',
      version: 1,
      category: category,
      legacyBundle: legacy,
      document: doc,
      theme: BibleTheme.builtin(themeId),
      exportSettings: doc.exportSettings,
      createdAt: DateTime.now().toUtc(),
    );
  }

  static List<BibleBlock> _blocksForSection(String sectionId) {
    return switch (sectionId) {
      'direction' => [
        _block(BibleBlockKind.narrative, rowSpan: 2),
        _block(BibleBlockKind.heroImage, rowSpan: 4),
        _block(BibleBlockKind.moodboardRefs, rowSpan: 3),
      ],
      'concept' => [
        _block(BibleBlockKind.narrative, rowSpan: 2),
        _block(BibleBlockKind.colorPalette, colSpan: 6, rowSpan: 2),
        _block(BibleBlockKind.chipSelect, colSpan: 6, rowSpan: 2),
      ],
      'camera' => [
        _block(BibleBlockKind.specsTable, colSpan: 8, rowSpan: 3),
        _block(BibleBlockKind.heroImage, colSpan: 4, rowSpan: 3),
        _block(BibleBlockKind.telemetry, rowSpan: 2),
      ],
      'lighting' => [
        _block(BibleBlockKind.narrative, rowSpan: 2),
        _block(BibleBlockKind.heroImage, rowSpan: 4),
        _block(BibleBlockKind.equipmentList, colSpan: 6, rowSpan: 3),
        _block(BibleBlockKind.telemetry, colSpan: 6, rowSpan: 3),
      ],
      'moodboard' => [
        _block(BibleBlockKind.moodboardRefs, rowSpan: 6),
      ],
      'exposure' => [
        _block(BibleBlockKind.narrative, rowSpan: 2),
        _block(BibleBlockKind.specsTable, rowSpan: 3),
      ],
      'optics' => [
        _block(BibleBlockKind.specsTable, rowSpan: 3),
        _block(BibleBlockKind.heroImage, rowSpan: 3),
      ],
      'color_image' => [
        _block(BibleBlockKind.colorPalette, rowSpan: 2),
        _block(BibleBlockKind.narrative, rowSpan: 2),
      ],
      'location' => [
        _block(BibleBlockKind.heroImage, rowSpan: 4),
        _block(BibleBlockKind.telemetry, rowSpan: 2),
      ],
      'workflow' => [
        _block(BibleBlockKind.workflowPipeline, rowSpan: 2),
        _block(BibleBlockKind.narrative, rowSpan: 2),
      ],
      _ => [_block(BibleBlockKind.narrative, rowSpan: 3)],
    };
  }

  static BibleBlock _block(
    BibleBlockKind type, {
    int colSpan = 12,
    int rowSpan = 2,
  }) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return BibleBlock(
      id: 'block_${type.name}_$stamp',
      type: type,
      layout: BibleBlockLayout(colSpan: colSpan, rowSpan: rowSpan),
      content: {'label': type.label},
    );
  }
}
