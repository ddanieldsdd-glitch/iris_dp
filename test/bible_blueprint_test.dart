import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/bible_block_catalog.dart';
import 'package:iris_dp/features/visual_bible/bible_blueprint.dart';
import 'package:iris_dp/features/visual_bible/bible_section_style_store.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BibleBlueprintType visibility', () {
    test('fiction shows all sections', () {
      expect(BibleBlueprintType.fiction.defaultHiddenSectionIds, isEmpty);
    });

    test('commercial hides camera tests and workflow', () {
      expect(
        BibleBlueprintType.commercial.defaultHiddenSectionIds,
        {BibleSectionId.cameraTests, BibleSectionId.workflow},
      );
    });

    test('documentary hides camera tests only', () {
      expect(
        BibleBlueprintType.documentary.defaultHiddenSectionIds,
        {BibleSectionId.cameraTests},
      );
    });
  });

  group('BibleSectionRenderer', () {
    test('detects corrupted aesthetic templates', () {
      expect(BibleSectionRenderer.isCorruptedAesthetic('cinematic'), isTrue);
      expect(BibleSectionRenderer.isCorruptedAesthetic('moodboard'), isFalse);
      expect(BibleSectionRenderer.isCorruptedAesthetic('blocks_lighting'), isFalse);
    });

    test('builtin renderer keys are stable', () {
      expect(
        BibleSectionRenderer.builtinFor(BibleSectionId.moodboard),
        BibleSectionRenderer.moodboard,
      );
      expect(
        BibleSectionRenderer.builtinFor(BibleSectionId.lighting),
        BibleSectionRenderer.blocksLighting,
      );
    });
  });

  group('BibleSectionStyleStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves and loads styles without touching template semantics', () async {
      await BibleSectionStyleStore.save(
        42,
        BibleSectionId.lighting,
        BibleSectionStyle.technical,
      );
      final loaded = await BibleSectionStyleStore.load(
        42,
        BibleSectionId.lighting,
      );
      expect(loaded, BibleSectionStyle.technical);
    });
  });

  group('BibleBlueprintPacks', () {
    test('lighting fiction includes diagram and telemetry', () {
      final blocks = BibleBlueprintPacks.blocksFor(
        BibleSectionId.lighting,
        BibleBlueprintType.fiction,
      );
      expect(blocks, contains(BibleBlockKind.lightingDiagram));
      expect(blocks, contains(BibleBlockKind.telemetry));
    });

    test('commercial color emphasizes palette', () {
      final blocks = BibleBlueprintPacks.blocksFor(
        BibleSectionId.colorImage,
        BibleBlueprintType.commercial,
      );
      expect(blocks.first, BibleBlockKind.colorPalette);
    });
  });
}
