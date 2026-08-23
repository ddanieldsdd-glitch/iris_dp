import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:iris_dp/shared/visual_bible/bible_stitch_module_registry.dart';
import 'package:iris_dp/shared/visual_bible/bible_subsection_kind_catalog.dart';
import 'package:iris_dp/shared/visual_bible/bible_widget_layout_packer.dart';
import 'package:iris_dp/shared/visual_bible/bible_widget_size.dart';

void main() {
  group('BibleSectionField S/M/L', () {
    test('legacy field without size defaults to L', () {
      const field = BibleSectionField(key: 'narrative', label: 'Narrativa');
      expect(field.size, BibleWidgetSize.large);
    });

    test('fromJson parses kind and size', () {
      final field = BibleSectionField.fromJson({
        'key': 'filmRefs',
        'label': 'Refs',
        'type': 'blocks',
        'kind': 'cardDeck',
        'size': 'M',
      });
      expect(field.kind, BibleSubsectionKindId.cardDeck);
      expect(field.size, BibleWidgetSize.medium);
    });

    test('enrichField infers kind from stitch module', () {
      final raw = const BibleSectionField(
        key: 'globalMetrics',
        label: 'Métricas',
        type: BibleSectionFieldType.blocks,
      );
      final enriched = BibleSectionFieldsConfig.enrichField(
        BibleSectionId.lighting,
        raw,
      );
      expect(enriched.kind, BibleSubsectionKindId.telemetryPanel);
      expect(enriched.binding, 'globalMetrics');
    });

    test('defaultsFor lighting include kinds', () {
      final fields = BibleSectionFieldsConfig.defaultsFor(BibleSectionId.lighting);
      final metrics = fields.firstWhere((f) => f.key == 'globalMetrics');
      expect(metrics.kind, BibleSubsectionKindId.telemetryPanel);
      expect(metrics.size, BibleWidgetSize.medium);
    });
  });

  group('BibleWidgetLayoutPacker', () {
    BibleWidgetLayoutItem item(String key, BibleWidgetSize size) =>
        BibleWidgetLayoutItem.fromSize(
          key: key,
          size: size,
          child: SizedBox(key: Key(key)),
        );

    test('packs S+S+S in one row when 12 cols effective', () {
      final rows = BibleWidgetLayoutPacker.packRows(
        [
          item('a', BibleWidgetSize.small),
          item('b', BibleWidgetSize.small),
          item('c', BibleWidgetSize.small),
        ],
        12,
      );
      expect(rows.length, 1);
      expect(rows.first.length, 3);
    });

    test('packs S+M in one row', () {
      final rows = BibleWidgetLayoutPacker.packRows(
        [
          item('a', BibleWidgetSize.small),
          item('b', BibleWidgetSize.medium),
        ],
        12,
      );
      expect(rows.length, 1);
      expect(rows.first.map((i) => i.key), ['a', 'b']);
    });

    test('L alone fills a row', () {
      final rows = BibleWidgetLayoutPacker.packRows(
        [item('hero', BibleWidgetSize.large)],
        12,
      );
      expect(rows.length, 1);
      expect(rows.first.single.key, 'hero');
    });

    test('collapses to single column layout on narrow effective cols', () {
      final rows = BibleWidgetLayoutPacker.packRows(
        [
          item('a', BibleWidgetSize.small),
          item('b', BibleWidgetSize.medium),
        ],
        4,
      );
      expect(rows.length, 2);
    });

    test('effectiveColumns returns 1 for narrow width', () {
      expect(BibleWidgetLayoutPacker.effectiveColumns(300), 1);
    });
  });

  group('Stitch modules annotated', () {
    test('concept modules have subsectionKind', () {
      for (final module in BibleStitchModuleRegistry.modulesFor(
        BibleSectionId.concept,
      )) {
        if (module.legacyOnly) continue;
        expect(
          module.subsectionKind,
          isNotNull,
          reason: module.key,
        );
      }
    });
  });
}
