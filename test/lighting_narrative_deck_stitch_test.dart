import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:iris_dp/shared/visual_bible/bible_stitch_module_registry.dart';

void main() {
  test('lighting stitch defaults use narrative deck keys', () {
    final keys = BibleStitchModuleRegistry.defaultFieldsFor(BibleSectionId.lighting)
        .map((f) => f.key)
        .toList();
    expect(keys, [
      'overview',
      'lightBehaviors',
      'filmRefs',
      'locationLights',
    ]);
  });

  test('lighting normalize upgrades legacy layouts to deck', () {
    final legacy = [
      BibleSectionField(key: 'narrative', label: 'N'),
      BibleSectionField(key: 'narrativeStory', label: 'S'),
      BibleSectionField(key: 'references', label: 'R'),
    ];
    final normalized = BibleStitchModuleRegistry.normalizeFields(
      BibleSectionId.lighting,
      legacy,
    );
    expect(
      normalized.map((f) => f.key).toList(),
      [
        'overview',
        'lightBehaviors',
        'filmRefs',
        'locationLights',
      ],
    );
  });
}
