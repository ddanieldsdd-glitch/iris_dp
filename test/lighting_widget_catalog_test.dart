import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:iris_dp/shared/visual_bible/bible_stitch_module_registry.dart';
import 'package:iris_dp/shared/visual_bible/bible_subsection_kind_catalog.dart';
import 'package:iris_dp/shared/visual_bible/lighting_widget_catalog.dart';

void main() {
  test('catálogo cubre todos los fieldWidgets de Iluminación', () {
    expect(
      LightingWidgetCatalog.coversFieldWidgetKeys({
        'overview',
        'globalMetrics',
        'lightBehaviors',
        'filmRefs',
        'locationLights',
        'lightStyles',
        'lightingTagRefs',
        'diagrams',
      }),
      isTrue,
    );
  });

  test('módulos Stitch de lighting tienen kind y familia', () {
    expect(LightingWidgetCatalog.stitchModulesAnnotated(), isTrue);
    final behaviors = BibleStitchModuleRegistry.module(
      BibleSectionId.lighting,
      'lightBehaviors',
    );
    expect(behaviors?.subsectionKind, BibleSubsectionKindId.behaviorMosaic);
    expect(behaviors?.contentFamily, BibleWidgetContentFamily.cinematic);

    final metrics = BibleStitchModuleRegistry.module(
      BibleSectionId.lighting,
      'globalMetrics',
    );
    expect(metrics?.subsectionKind, BibleSubsectionKindId.telemetryPanel);
    expect(metrics?.contentFamily, BibleWidgetContentFamily.technical);
    expect(metrics?.label, 'Sensación de temperatura');

    final diagrams = BibleStitchModuleRegistry.module(
      BibleSectionId.lighting,
      'diagrams',
    );
    expect(diagrams?.subsectionKind, BibleSubsectionKindId.setupList);
    expect(diagrams?.contentFamily, BibleWidgetContentFamily.technical);
  });

  test('nested overview es cinematic; métricas son slot técnico', () {
    final nested = LightingWidgetCatalog.nestedForSlot('overview');
    expect(
      nested.every(
        (e) => e.contentFamily == BibleWidgetContentFamily.cinematic,
      ),
      isTrue,
    );
    expect(nested.any((e) => e.id == 'nested_global_metrics'), isFalse);
    final metrics = LightingWidgetCatalog.forSlot('globalMetrics');
    expect(metrics?.contentFamily, BibleWidgetContentFamily.technical);
    expect(metrics?.subsectionKind, BibleSubsectionKindId.telemetryPanel);
  });

  test('cada slot del catálogo tiene entrada forSlot', () {
    for (final key in LightingWidgetCatalog.slotKeys) {
      expect(LightingWidgetCatalog.forSlot(key), isNotNull);
    }
  });
}
