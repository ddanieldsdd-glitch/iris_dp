import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/features/visual_bible/bible_blueprint.dart';
import 'package:iris_dp/features/visual_bible/bible_preset_bundle.dart';
import 'package:iris_dp/features/visual_bible/bible_tech_sync.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_completion.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

void main() {
  group('BibleBuiltinPresets', () {
    test('incluye ficción, comercial y documental', () {
      expect(BibleBuiltinPresets.all.length, 3);
      expect(
        BibleBuiltinPresets.byId(BibleBuiltinPresets.fictionNoirId)?.blueprint,
        BibleBlueprintType.fiction,
      );
      expect(
        BibleBuiltinPresets.byId(BibleBuiltinPresets.commercialCleanId)
            ?.blueprint,
        BibleBlueprintType.commercial,
      );
      expect(
        BibleBuiltinPresets.byId(BibleBuiltinPresets.documentaryObsId)
            ?.blueprint,
        BibleBlueprintType.documentary,
      );
    });

    test('seed de ficción tiene colorimetrías y Kelvin', () {
      final seed = BibleBuiltinPresets.fictionNoir.sampleSeed!;
      expect(seed.colorBlocks.length, greaterThanOrEqualTo(2));
      expect(seed.visualBibleFields['lightSource'], '3200K');
      expect(seed.visualBibleFields['keyFillRatioNight'], '4:1');
    });

    test('bundle encode/decode roundtrip', () {
      final original = BibleBuiltinPresets.fictionNoir;
      final decoded = BiblePresetBundle.tryDecode(original.encode());
      expect(decoded, isNotNull);
      expect(decoded!.id, original.id);
      expect(decoded.blueprint, original.blueprint);
      expect(decoded.sampleSeed?.colorBlocks.length,
          original.sampleSeed?.colorBlocks.length);
    });
  });

  group('BibleTechSync', () {
    test('parseKelvin', () {
      expect(BibleTechSync.parseKelvin('3200K'), 3200);
      expect(BibleTechSync.parseKelvin('5600'), 5600);
      expect(BibleTechSync.parseKelvin(null), isNull);
    });

    test('applyKelvinToData', () {
      final data = VisualBibleData(id: 1, projectId: 1);
      BibleTechSync.applyKelvinToData(data, 3200);
      expect(data.lightSource, '3200K');
    });

    test('applyContrastRatio', () {
      final data = VisualBibleData(id: 1, projectId: 1);
      BibleTechSync.applyContrastRatio(data, ratio: '4:1');
      expect(data.keyFillRatioNight, '4:1');
    });
  });

  group('bibleSectionCompletion', () {
    test('exposure usa campos técnicos', () {
      final empty = VisualBibleData(id: 1, projectId: 1);
      expect(bibleSectionCompletion(empty, BibleSectionId.exposure), 0);

      final filled = VisualBibleData(id: 1, projectId: 1)
        ..exposureNarrativeIntent = 'test'
        ..highlightBehavior = 'protect'
        ..shadowBehavior = 'detail'
        ..nativeIso = 800
        ..defaultTStop = 'T2.8';
      expect(
        bibleSectionCompletion(filled, BibleSectionId.exposure),
        1.0,
      );
    });

    test('moodboard extended usa conteo', () {
      final data = VisualBibleData(id: 1, projectId: 1);
      expect(
        bibleSectionCompletionExtended(
          data: data,
          sectionId: BibleSectionId.moodboard,
          moodboardCount: 0,
        ),
        0,
      );
      expect(
        bibleSectionCompletionExtended(
          data: data,
          sectionId: BibleSectionId.moodboard,
          moodboardCount: 6,
        ),
        greaterThan(0.5),
      );
    });
  });
}
