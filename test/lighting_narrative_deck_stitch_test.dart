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
      'globalMetrics',
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
        'globalMetrics',
        'lightBehaviors',
        'filmRefs',
        'locationLights',
      ],
    );
  });

  test('normalize inserta globalMetrics y deduplica locationLights', () {
    final normalized = BibleStitchModuleRegistry.normalizeFields(
      BibleSectionId.lighting,
      [
        BibleSectionField(key: 'overview', label: 'Overview'),
        BibleSectionField(key: 'lightBehaviors', label: 'Behaviors'),
        BibleSectionField(key: 'filmRefs', label: 'Film'),
        BibleSectionField(key: 'locationLights', label: 'Loc A'),
        BibleSectionField(key: 'locationLights', label: 'Loc B'),
      ],
    );
    expect(
      normalized.map((f) => f.key).toList(),
      [
        'overview',
        'globalMetrics',
        'lightBehaviors',
        'filmRefs',
        'locationLights',
      ],
    );
    expect(normalized.where((f) => f.key == 'locationLights').length, 1);
  });
}
