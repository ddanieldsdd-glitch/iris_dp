import '../model/bible_block.dart';
import '../../bible_block_catalog.dart';
import '../model/bible_block_layout.dart';
import '../model/bible_document.dart';
import '../model/bible_page.dart';
import '../theme/bible_theme.dart';
import 'bible_template_package.dart';

/// Plantillas V2 built-in (documento completo, no legacy bundle).
abstract final class BibleV2BuiltinTemplates {
  static const categoryCinematic = 'Cinematográfica';
  static const categoryTechnical = 'Técnica';
  static const categoryMinimalist = 'Minimalista';
  static const categoryCommercial = 'Comercial';
  static const categoryDocumentary = 'Documental';
  static const categoryEditorial = 'Editorial';

  static List<BibleTemplatePackage> get all => [
    cinematic,
    technical,
    minimalist,
    commercial,
    documentary,
  ];

  static BibleTemplatePackage get cinematic => _pack(
    id: 'v2_cinematic',
    name: 'Cinematic DP Bible',
    description:
        'Estructura cinematográfica con dirección, concepto, cámara, luz y color.',
    category: categoryCinematic,
    themeId: BibleThemeIds.cinematic,
    pages: [
      _page('Dirección', 'direction', [
        _block(BibleBlockKind.narrative, colSpan: 12, rowSpan: 2),
        _block(BibleBlockKind.heroImage, colSpan: 12, rowSpan: 4),
        _block(BibleBlockKind.moodboardRefs, colSpan: 12, rowSpan: 3),
      ]),
      _page('Concepto', 'concept', [
        _block(BibleBlockKind.narrative, colSpan: 12, rowSpan: 2),
        _block(BibleBlockKind.chipSelect, colSpan: 6, rowSpan: 2),
        _block(BibleBlockKind.colorPalette, colSpan: 6, rowSpan: 2),
      ]),
      _page('Cámara', 'camera', [
        _block(BibleBlockKind.specsTable, colSpan: 8, rowSpan: 3),
        _block(BibleBlockKind.heroImage, colSpan: 4, rowSpan: 3),
        _block(BibleBlockKind.telemetry, colSpan: 12, rowSpan: 2),
      ]),
      _page('Iluminación', 'lighting', [
        _block(BibleBlockKind.narrative, colSpan: 12, rowSpan: 2),
        _block(BibleBlockKind.equipmentList, colSpan: 6, rowSpan: 3),
        _block(BibleBlockKind.workflowPipeline, colSpan: 6, rowSpan: 3),
      ]),
    ],
  );

  static BibleTemplatePackage get technical => _pack(
    id: 'v2_technical',
    name: 'Technical Scout Bible',
    description: 'Enfoque técnico con specs, telemetría y pipeline de workflow.',
    category: categoryTechnical,
    themeId: BibleThemeIds.technical,
    pages: [
      _page('Specs', 'specs', [
        _block(BibleBlockKind.specsTable, colSpan: 12, rowSpan: 4),
        _block(BibleBlockKind.telemetry, colSpan: 12, rowSpan: 2),
      ]),
      _page('Equipo', 'gear', [
        _block(BibleBlockKind.equipmentList, colSpan: 12, rowSpan: 3),
        _block(BibleBlockKind.workflowPipeline, colSpan: 12, rowSpan: 2),
      ]),
    ],
  );

  static BibleTemplatePackage get minimalist => _pack(
    id: 'v2_minimalist',
    name: 'Minimalist Bible',
    description: 'Dos páginas esenciales: intención + referencias.',
    category: categoryMinimalist,
    themeId: BibleThemeIds.minimalist,
    pages: [
      _page('Intención', 'intent', [
        _block(BibleBlockKind.narrative, colSpan: 12, rowSpan: 3),
      ]),
      _page('Referencias', 'refs', [
        _block(BibleBlockKind.heroImage, colSpan: 12, rowSpan: 4),
        _block(BibleBlockKind.moodboardRefs, colSpan: 12, rowSpan: 3),
      ]),
    ],
  );

  static BibleTemplatePackage get commercial => _pack(
    id: 'v2_commercial',
    name: 'Commercial Clean',
    description: 'Plantilla ágil para spots y branded content.',
    category: categoryCommercial,
    themeId: BibleThemeIds.minimalist,
    pages: [
      _page('Concepto', 'concept', [
        _block(BibleBlockKind.narrative, colSpan: 12, rowSpan: 2),
        _block(BibleBlockKind.heroImage, colSpan: 12, rowSpan: 4),
      ]),
      _page('Look', 'look', [
        _block(BibleBlockKind.colorPalette, colSpan: 12, rowSpan: 2),
        _block(BibleBlockKind.moodboardRefs, colSpan: 12, rowSpan: 3),
      ]),
    ],
  );

  static BibleTemplatePackage get documentary => _pack(
    id: 'v2_documentary',
    name: 'Documentary Observational',
    description: 'Narrativa + locaciones + workflow documental.',
    category: categoryDocumentary,
    themeId: BibleThemeIds.cinematic,
    pages: [
      _page('Enfoque', 'approach', [
        _block(BibleBlockKind.narrative, colSpan: 12, rowSpan: 3),
        _block(BibleBlockKind.chipSelect, colSpan: 12, rowSpan: 2),
      ]),
      _page('Producción', 'production', [
        _block(BibleBlockKind.workflowPipeline, colSpan: 12, rowSpan: 2),
        _block(BibleBlockKind.equipmentList, colSpan: 12, rowSpan: 3),
      ]),
    ],
  );

  static BibleTemplatePackage? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  static int widgetCount(BibleTemplatePackage pack) {
    final doc = pack.document;
    if (doc == null) return 0;
    return doc.pages.fold<int>(0, (n, p) => n + p.blocks.length);
  }

  static Set<BibleBlockKind> widgetTypes(BibleTemplatePackage pack) {
    final doc = pack.document;
    if (doc == null) return const {};
    return {
      for (final page in doc.pages)
        for (final block in page.blocks) block.type,
    };
  }

  static BibleTemplatePackage _pack({
    required String id,
    required String name,
    required String description,
    required String category,
    required String themeId,
    required List<BiblePage> pages,
  }) {
    final doc = BibleDocument(
      projectId: 0,
      themeId: themeId,
      pages: pages,
      updatedAt: DateTime.now().toUtc(),
    );
    return BibleTemplatePackage(
      id: id,
      name: name,
      description: description,
      author: 'IRIS DP',
      version: 1,
      category: category,
      document: doc,
      theme: BibleTheme.builtin(themeId),
      createdAt: DateTime.now().toUtc(),
    );
  }

  static BiblePage _page(String label, String slug, List<BibleBlock> blocks) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return BiblePage(
      id: 'page_${slug}_$stamp',
      groupId: 'main',
      label: label,
      sortOrder: 0,
      blocks: blocks,
    );
  }

  static BibleBlock _block(
    BibleBlockKind type, {
    int colSpan = 12,
    int rowSpan = 2,
    int col = 0,
    int row = 0,
  }) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return BibleBlock(
      id: 'block_${type.name}_$stamp',
      type: type,
      layout: BibleBlockLayout(col: col, row: row, colSpan: colSpan, rowSpan: rowSpan),
      content: _defaultContent(type),
    );
  }

  static Map<String, dynamic> _defaultContent(BibleBlockKind type) =>
      switch (type) {
        BibleBlockKind.narrative => {
          'title': 'Intención narrativa',
          'body': '',
        },
        BibleBlockKind.chipSelect => {
          'chips': ['TENSIÓN', 'INTIMIDAD', 'ESPERA'],
          'selected': <String>[],
        },
        BibleBlockKind.colorPalette => {
          'colors': [
            {'hex': '#1E1E1E', 'name': 'Sombra'},
            {'hex': '#2997FF', 'name': 'Acento'},
          ],
        },
        BibleBlockKind.telemetry => {
          'metrics': [
            {'label': 'Kelvin', 'value': '3200K'},
            {'label': 'Ratio', 'value': '4:1'},
          ],
        },
        BibleBlockKind.equipmentList => {
          'items': ['ARRI SkyPanel S60-C', 'Neg fill'],
        },
        BibleBlockKind.specsTable => {
          'columns': ['label', 'value'],
          'rows': [
            {'label': 'Camera', 'value': ''},
            {'label': 'Lens', 'value': ''},
            {'label': 'ISO', 'value': ''},
          ],
        },
        BibleBlockKind.workflowPipeline => {
          'steps': ['Prepro', 'Rodaje', 'Grade', 'Entrega'],
        },
        BibleBlockKind.heroImage ||
        BibleBlockKind.moodboardRefs => {'label': 'Referencia visual'},
        _ => {'label': type.label},
      };
}
