import '../bible_block_catalog.dart';
import 'bible_block_schemas.dart';

/// Contrato de producto por [BibleBlockKind]:
/// canvas + inspector + JSON + PDF. El picker solo ofrece kinds `live`.
abstract final class BibleBlockContract {
  static bool isComplete(BibleBlockKind kind) =>
      kind.status == BibleBlockStatus.live;

  static Iterable<BibleBlockKind> get completeKinds =>
      BibleBlockKind.values.where(isComplete);

  static Map<String, dynamic> defaultContentForSubsection(
    String subsectionKind,
  ) => BibleBlockSchemas.forSubsection(subsectionKind);

  static Map<String, dynamic> defaultContent(BibleBlockKind kind) =>
      switch (kind) {
        BibleBlockKind.narrative => BibleBlockSchemas.taggedText(),
        BibleBlockKind.chipSelect => {
          'chips': <String>['TENSIÓN'],
          'selected': <String>[],
        },
        BibleBlockKind.colorPalette => {
          'colors': [
            {'hex': '#1E1E1E', 'name': 'DEEP SHADOW'},
          ],
        },
        BibleBlockKind.telemetry => {
          'metrics': [
            {'label': 'Kelvin', 'value': ''},
          ],
        },
        BibleBlockKind.equipmentList => {'items': <String>[]},
        BibleBlockKind.specsTable => {
          'columns': ['label', 'value'],
          'rows': [
            {'label': '', 'value': ''},
          ],
        },
        BibleBlockKind.workflowPipeline => {
          'steps': List<String>.from(kBibleWorkflowDefaultSteps),
        },
        BibleBlockKind.lightingDiagram => {
          'label': 'Setup',
          'nodes': <Map<String, dynamic>>[],
        },
        BibleBlockKind.moodboardRefs => {'images': <Map<String, dynamic>>[]},
        BibleBlockKind.heroImage => {'label': 'Imagen'},
        BibleBlockKind.dynamicBlocks => {'blocks': <Map<String, dynamic>>[]},
        BibleBlockKind.text => {
          'label': kind.label,
          'text': '',
          'points': <Map<String, dynamic>>[],
        },
      };
}
