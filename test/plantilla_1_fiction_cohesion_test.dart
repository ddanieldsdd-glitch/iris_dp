import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/bible_blueprint.dart';
import 'package:iris_dp/features/visual_bible/bible_preset_bundle.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:iris_dp/shared/visual_bible/bible_stitch_module_registry.dart';
import 'package:iris_dp/shared/visual_bible/bible_subsection_kind_catalog.dart';

void main() {
  group('Plantilla 1 availability', () {
    test('solo Ficción está disponible', () {
      expect(BibleBlueprintType.fiction.isAvailable, isTrue);
      expect(BibleBlueprintType.commercial.isAvailable, isFalse);
      expect(BibleBlueprintType.documentary.isAvailable, isFalse);
    });

    test('solo Cinematic está disponible', () {
      expect(BibleSectionStyle.cinematic.isAvailable, isTrue);
      expect(BibleSectionStyle.technical.isAvailable, isFalse);
      expect(BibleSectionStyle.minimalist.isAvailable, isFalse);
    });

    test('Plantilla 1 es ficción cinematic y resuelve ids legacy', () {
      final p = BibleBuiltinPresets.plantilla1;
      expect(p.name, 'Plantilla 1');
      expect(p.blueprint, BibleBlueprintType.fiction);
      expect(p.isAvailable, isTrue);
      expect(BibleBuiltinPresets.byId(BibleBuiltinPresets.fictionNoirId), p);
      expect(BibleBuiltinPresets.byId(BibleBuiltinPresets.plantilla1Id), p);
      expect(BibleBuiltinPresets.available, [p]);
      expect(
        p.sectionStyles[BibleSectionId.lighting],
        BibleSectionStyle.cinematic,
      );
    });

    test('comercial y documental no son aplicables', () {
      expect(BibleBuiltinPresets.commercialClean.isAvailable, isFalse);
      expect(BibleBuiltinPresets.documentaryObs.isAvailable, isFalse);
    });

    test('defaultStyleForSection es cinematic (Plantilla 1)', () {
      expect(
        defaultStyleForSection(
          BibleSectionId.lighting,
          BibleBlueprintType.fiction,
        ),
        BibleSectionStyle.cinematic,
      );
    });
  });

  group('BibleSubsectionKindCatalog', () {
    test('cubre los tipos base y de contenedor con icono y fieldType', () {
      expect(BibleSubsectionKindCatalog.all.length, 10);
      expect(
        BibleSubsectionKindCatalog.byId(BibleSubsectionKindId.textField)!
            .fieldType,
        BibleSectionFieldType.text,
      );
      expect(
        BibleSubsectionKindCatalog.byId(BibleSubsectionKindId.narrativeIntent)!
            .fieldType,
        BibleSectionFieldType.narrative,
      );
      expect(
        BibleSubsectionKindCatalog.byId(BibleSubsectionKindId.moodboardRefs)!
            .fieldType,
        BibleSectionFieldType.references,
      );
      expect(
        BibleSubsectionKindCatalog.byId(BibleSubsectionKindId.referenceImages)!
            .fieldType,
        BibleSectionFieldType.image,
      );
      expect(
        BibleSubsectionKindCatalog.byId(BibleSubsectionKindId.dynamicBlocks)!
            .fieldType,
        BibleSectionFieldType.blocks,
      );
      expect(
        BibleSubsectionKindCatalog.byId(BibleSubsectionKindId.headerTags)!
            .icon,
        Icons.label_outline,
      );
      expect(
        BibleSubsectionKindCatalog.byId(BibleSubsectionKindId.heroWithCaption)!
            .fieldType,
        BibleSectionFieldType.image,
      );
      expect(
        BibleSubsectionKindCatalog.byId(BibleSubsectionKindId.paletteTarget)!
            .fieldType,
        BibleSectionFieldType.references,
      );
    });

    test('módulos de Iluminación anotan subsectionKind', () {
      final mods =
          BibleStitchModuleRegistry.modulesFor(BibleSectionId.lighting);
      final byKey = {for (final m in mods) m.key: m};
      expect(
        byKey['overview']!.subsectionKind,
        BibleSubsectionKindId.narrativeIntent,
      );
      expect(
        byKey['lightBehaviors']!.subsectionKind,
        BibleSubsectionKindId.dynamicBlocks,
      );
      expect(
        byKey['filmRefs']!.subsectionKind,
        BibleSubsectionKindId.dynamicBlocks,
      );
      expect(
        byKey['locationLights']!.subsectionKind,
        BibleSubsectionKindId.dynamicBlocks,
      );
      expect(
        byKey['lightBehaviors']!.catalogKind.icon,
        Icons.view_module_outlined,
      );
    });
  });

  group('lighting Plantilla 1 deck', () {
    test('defaults y normalize usan deck cinematic', () {
      final keys = BibleStitchModuleRegistry.defaultFieldsFor(
        BibleSectionId.lighting,
      ).map((f) => f.key).toList();
      expect(keys, [
        'overview',
        'lightBehaviors',
        'filmRefs',
        'locationLights',
      ]);

      final normalized = BibleStitchModuleRegistry.normalizeFields(
        BibleSectionId.lighting,
        [
          BibleSectionField(key: 'lightStyles', label: 'Legacy'),
          BibleSectionField(key: 'lightingTagRefs', label: 'Tags'),
        ],
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

      final both = BibleStitchModuleRegistry.normalizeFields(
        BibleSectionId.lighting,
        [
          BibleSectionField(key: 'overview', label: 'Overview'),
          BibleSectionField(key: 'lightBehaviors', label: 'Behaviors'),
          BibleSectionField(key: 'lightStyles', label: 'Legacy styles'),
          BibleSectionField(key: 'filmRefs', label: 'Film'),
        ],
      );
      expect(
        both.map((f) => f.key).toList(),
        ['overview', 'lightBehaviors', 'filmRefs'],
      );
    });
  });
}
