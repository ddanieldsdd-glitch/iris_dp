import 'dart:convert';

import '../model/bible_block.dart';
import '../model/bible_block_layout.dart';
import '../../bible_block_catalog.dart';

/// Extiende freeform `contentJson` con bloques v2 sin romper fields legacy.
abstract final class FreeformV2BlocksCodec {
  static const blocksKey = 'v2Blocks';

  static List<BibleBlock> parseBlocks(String? contentJson) {
    if (contentJson == null || contentJson.isEmpty) return const [];
    try {
      final decoded = jsonDecode(contentJson);
      if (decoded is! Map) return const [];
      final raw = decoded[blocksKey];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => BibleBlock.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String mergeBlocksIntoContentJson(
    String? contentJson,
    List<BibleBlock> blocks,
  ) {
    Map<String, dynamic> map = {};
    if (contentJson != null && contentJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(contentJson);
        if (decoded is Map) {
          map = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    map[blocksKey] = blocks.map((b) => b.toJson()).toList();
    return jsonEncode(map);
  }

  /// Layout modular inicial para pantallas custom nuevas.
  static String starterContentJson(String sectionLabel) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final blocks = <BibleBlock>[
      BibleBlock(
        id: 'narrative_$stamp',
        type: BibleBlockKind.narrative,
        layout: const BibleBlockLayout(colSpan: 12, rowSpan: 2),
        content: {
          'title': 'Intención narrativa',
          'hint': 'Intención narrativa de «$sectionLabel»…',
          'body': '',
        },
      ),
      BibleBlock(
        id: 'hero_$stamp',
        type: BibleBlockKind.heroImage,
        layout: const BibleBlockLayout(colSpan: 12, rowSpan: 4),
        content: {'label': 'Hero visual', 'aspectRatio': '16:9'},
      ),
      BibleBlock(
        id: 'refs_$stamp',
        type: BibleBlockKind.moodboardRefs,
        layout: const BibleBlockLayout(colSpan: 12, rowSpan: 3),
        content: {'label': 'Referencias visuales'},
      ),
    ];
    return mergeBlocksIntoContentJson(null, blocks);
  }
}
