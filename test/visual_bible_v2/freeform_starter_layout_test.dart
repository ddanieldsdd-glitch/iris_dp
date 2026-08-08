import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/v2/migration/freeform_v2_blocks_codec.dart';
import 'package:iris_dp/features/visual_bible/bible_block_catalog.dart';

void main() {
  test('starterContentJson crea bloques narrative, hero y refs', () {
    final json = FreeformV2BlocksCodec.starterContentJson('Mi pantalla');
    final blocks = FreeformV2BlocksCodec.parseBlocks(json);

    expect(blocks, hasLength(3));
    expect(blocks.map((b) => b.type), contains(BibleBlockKind.narrative));
    expect(blocks.map((b) => b.type), contains(BibleBlockKind.heroImage));
    expect(blocks.map((b) => b.type), contains(BibleBlockKind.moodboardRefs));
  });
}
