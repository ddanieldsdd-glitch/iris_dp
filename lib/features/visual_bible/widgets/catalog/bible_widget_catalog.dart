import '../../bible_block_catalog.dart';
import '../../v2/bible_block_schemas.dart';
import 'direction/direction_acts_widget.dart';
import 'direction/direction_visual_strategy_widget.dart';
import 'shared/bible_point_list_widget.dart';
import 'shared/bible_references_widget.dart';
import 'shared/bible_tagged_text_widget.dart';

/// Pantalla de origen de un widget del catálogo.
enum BibleWidgetCatalogOrigin { shared, direction }

/// Entrada de registro (Pasada 2: no se cablea al compositor).
class BibleWidgetCatalogEntry {
  final String id;
  final BibleWidgetCatalogOrigin origin;
  final String label;
  final BibleBlockKind blockKind;
  final String subsectionKind;
  final Map<String, dynamic> Function() defaultContent;

  const BibleWidgetCatalogEntry({
    required this.id,
    required this.origin,
    required this.label,
    required this.blockKind,
    required this.subsectionKind,
    required this.defaultContent,
  });
}

/// Catálogo de widgets por pantalla + compartidos.
abstract final class BibleWidgetCatalog {
  static const taggedText = 'shared.tagged_text';
  static const pointList = 'shared.point_list';
  static const references = 'shared.references';
  static const visualStrategy = 'direction.visual_strategy';
  static const acts = 'direction.acts';

  static final List<BibleWidgetCatalogEntry> all = [
    BibleWidgetCatalogEntry(
      id: taggedText,
      origin: BibleWidgetCatalogOrigin.shared,
      label: 'Intención con tags',
      blockKind: BibleBlockKind.narrative,
      subsectionKind: BibleBlockSchemas.narrativeIntent,
      defaultContent: () => BibleBlockSchemas.taggedText(),
    ),
    BibleWidgetCatalogEntry(
      id: pointList,
      origin: BibleWidgetCatalogOrigin.shared,
      label: 'Lista de puntos',
      blockKind: BibleBlockKind.text,
      subsectionKind: BibleBlockSchemas.tonePoints,
      defaultContent: () =>
          BibleBlockSchemas.pointList(label: 'Tono y atmósfera'),
    ),
    BibleWidgetCatalogEntry(
      id: references,
      origin: BibleWidgetCatalogOrigin.shared,
      label: 'Referencias',
      blockKind: BibleBlockKind.moodboardRefs,
      subsectionKind: 'narrativeRefs',
      defaultContent: () => {'images': <Map<String, dynamic>>[]},
    ),
    BibleWidgetCatalogEntry(
      id: visualStrategy,
      origin: BibleWidgetCatalogOrigin.direction,
      label: 'Estrategia visual',
      blockKind: BibleBlockKind.text,
      subsectionKind: 'visualStrategy',
      defaultContent: () => {
        'pillars': [
          {'id': 'camera', 'title': 'Cámara', 'body': ''},
          {'id': 'blocking', 'title': 'Blocking', 'body': ''},
          {'id': 'pov', 'title': 'POV', 'body': ''},
        ],
        'extras': <Map<String, dynamic>>[],
      },
    ),
    BibleWidgetCatalogEntry(
      id: acts,
      origin: BibleWidgetCatalogOrigin.direction,
      label: 'Intención visual por acto',
      blockKind: BibleBlockKind.dynamicBlocks,
      subsectionKind: 'acts',
      defaultContent: () => {
        'acts': [
          {'phase': 'ACTO I', 'title': '', 'body': ''},
          {'phase': 'ACTO II', 'title': '', 'body': ''},
          {'phase': 'ACTO III', 'title': '', 'body': ''},
        ],
      },
    ),
  ];

  static BibleWidgetCatalogEntry? byId(String id) {
    for (final entry in all) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  static List<BibleWidgetCatalogEntry> forOrigin(
    BibleWidgetCatalogOrigin origin,
  ) => all.where((e) => e.origin == origin).toList();

  /// Tipos de widget Flutter registrados (para tests de render).
  static const widgetTypes = <Type>[
    BibleTaggedTextWidget,
    BiblePointListWidget,
    BibleReferencesWidget,
    DirectionVisualStrategyWidget,
    DirectionActsWidget,
  ];
}
