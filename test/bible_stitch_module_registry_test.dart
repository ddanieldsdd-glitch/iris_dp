import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:iris_dp/shared/visual_bible/bible_stitch_module_registry.dart';

void main() {
  test('defaultsFor concept uses decomposed Stitch keys', () {
    final fields = BibleSectionFieldsConfig.defaultsFor(BibleSectionId.concept);
    final keys = fields.map((f) => f.key).toSet();
    expect(keys, contains('colorPalette'));
    expect(keys.contains('filmGrain'), isFalse);
    expect(keys, isNot(contains('visualConcept')));
  });

  test('defaultsFor texture uses filmGrain diffusion sensorNoise', () {
    final fields = BibleSectionFieldsConfig.defaultsFor(BibleSectionId.texture);
    final keys = fields.map((f) => f.key).toSet();
    expect(keys, containsAll(['filmGrain', 'diffusion', 'sensorNoise', 'macroPreview']));
    expect(keys, isNot(contains('textureSettings')));
  });

  test('packForStyle restores Stitch modules for section', () {
    final fields = BibleSectionFieldsConfig.packForStyle(
      'cinematic',
      sectionId: BibleSectionId.texture,
      sectionLabel: 'Textura',
    );
    expect(fields.map((f) => f.key), contains('filmGrain'));
  });

  test('normalizeFields upgrades legacy concept monolith', () {
    final legacy = [
      const BibleSectionField(key: 'visualConcept', label: 'Concepto'),
      const BibleSectionField(key: 'narrative', label: 'Narrativa'),
    ];
    final normalized = BibleStitchModuleRegistry.normalizeFields(
      BibleSectionId.concept,
      legacy,
    );
    expect(normalized.map((f) => f.key), contains('colorPalette'));
  });

  test('normalizeFields strips visualConcept when modular slots exist', () {
    final mixed = [
      const BibleSectionField(key: 'visualConcept', label: 'Concepto'),
      const BibleSectionField(key: 'colorPalette', label: 'Paleta'),
      const BibleSectionField(key: 'narrative', label: 'Narrativa'),
    ];
    final normalized = BibleStitchModuleRegistry.normalizeFields(
      BibleSectionId.concept,
      mixed,
    );
    expect(normalized.map((f) => f.key), contains('colorPalette'));
    expect(normalized.map((f) => f.key), isNot(contains('visualConcept')));
  });

  test('normalizeFields strips textureSettings when modular slots exist', () {
    final mixed = [
      const BibleSectionField(key: 'textureSettings', label: 'Textura'),
      const BibleSectionField(key: 'filmGrain', label: 'Grano'),
    ];
    final normalized = BibleStitchModuleRegistry.normalizeFields(
      BibleSectionId.texture,
      mixed,
    );
    expect(normalized.map((f) => f.key), contains('filmGrain'));
    expect(normalized.map((f) => f.key), isNot(contains('textureSettings')));
  });

  test('direction registry keys are covered by stitch modules', () {
    final modules = BibleStitchModuleRegistry.modulesFor(BibleSectionId.direction)
        .where((m) => !m.legacyOnly)
        .map((m) => m.key)
        .toSet();
    expect(modules, containsAll(['header', 'narrative', 'toneStrategies', 'acts', 'keyFrame', 'transitions', 'references']));
  });

  test('normalizeFields upgrades legacy direction monolith narrative', () {
    final legacy = [
      const BibleSectionField(key: 'narrative', label: 'Dirección'),
    ];
    final normalized = BibleStitchModuleRegistry.normalizeFields(
      BibleSectionId.direction,
      legacy,
    );
    expect(normalized.map((f) => f.key), contains('header'));
  });

  test('missingModules lists slots not yet in fields', () {
    final fields = [
      const BibleSectionField(key: 'narrative', label: 'Narrativa'),
    ];
    final missing = BibleStitchModuleRegistry.missingModules(
      BibleSectionId.texture,
      fields,
    );
    expect(missing.map((m) => m.key), contains('filmGrain'));
  });

  test('lighting registry includes act1 and act2 slots', () {
    final modules = BibleStitchModuleRegistry.modulesFor(BibleSectionId.lighting)
        .where((m) => !m.legacyOnly)
        .map((m) => m.key)
        .toSet();
    expect(
      modules,
      containsAll([
        'narrativeStory',
        'colorLanguage',
        'textureLanguage',
        'lightSources',
        'gafferPhilosophy',
        'locationContext',
        'lightBehavior',
        'setTelemetry',
        'diagrams',
        'references',
      ]),
    );
  });

  test('normalizeFields strips legacy philosophy when act1 slots exist', () {
    final legacy = [
      const BibleSectionField(key: 'philosophy', label: 'Filosofía'),
      const BibleSectionField(key: 'narrativeStory', label: 'Historia'),
      const BibleSectionField(key: 'narrative', label: 'Narrativa'),
    ];
    final normalized = BibleStitchModuleRegistry.normalizeFields(
      BibleSectionId.lighting,
      legacy,
    );
    expect(normalized.map((f) => f.key), contains('narrativeStory'));
    expect(normalized.map((f) => f.key), isNot(contains('philosophy')));
  });
}
