import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../shared/visual_bible/bible_cards.dart';
import '../../../../shared/visual_bible/bible_equipment.dart';
import '../../../../shared/visual_bible/bible_table.dart';
import '../../../../shared/visual_bible/optics_points.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_card_editor.dart';
import '../bible_cards_widget.dart';
import '../bible_equipment_widget.dart';
import '../bible_point_panel.dart';
import '../bible_table_widget.dart';
import 'section_scaffold.dart';

/// Óptica: con qué lentes se rueda, qué carácter tienen y cómo se filtran.
///
/// Sus puntos se pintan con los widgets del catálogo. Lo que cada uno
/// guarda, y de dónde se lee lo escrito en biblias anteriores, está en
/// [OpticsPoints].
class OpticsSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final String? formatSectionContentJson;
  final BibleChanged onChanged;

  const OpticsSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    this.formatSectionContentJson,
    required this.onChanged,
  });

  static const _sectionId = BibleSectionId.optics;

  Future<void> _saveValue(WidgetRef ref, String key, String? value) => ref
      .read(databaseProvider)
      .saveBibleSectionFieldValue(data.id, _sectionId, key, value);

  static String? _orNull(String text) =>
      text.trim().isEmpty ? null : text.trim();

  /// Lo que Formato y el resto de la app leen de la configuración óptica.
  void _patchConfig(Map<String, dynamic> patch) {
    data.opticsConfigJson = jsonEncode({
      ...OpticsPoints.config(data.opticsConfigJson),
      ...patch,
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final config = OpticsPoints.config(data.opticsConfigJson);
    final values = BibleSectionFieldsConfig.parseValues(sectionContentJson);
    final labels = {
      for (final field in BibleSectionFieldsConfig.parse(
        sectionContentJson,
        _sectionId,
      ))
        field.key: field.label,
    };
    String label(String key, String fallback) => labels[key] ?? fallback;

    final philosophyValue = OpticsPoints.philosophyValue(
      values,
      config,
      lensPhilosophy: data.lensPhilosophy,
    );
    final characterCards = OpticsPoints.characterCards(values, config);
    final focalsValue = OpticsPoints.focalsValue(
      values,
      config,
      legacyFocals: data.primaryFocalLengths,
    );
    final filtrationMeters = OpticsPoints.filtrationMeters(
      values,
      config,
      filtrationNotes: data.filtrationNotes,
    );
    final maintenanceValue = OpticsPoints.maintenanceValue(values, config);
    final imageSource = BibleCardImageSource(
      projectId: projectId,
      bibleId: data.id,
      sectionId: _sectionId,
    );

    Widget kitEditor(List<BibleEquipmentItem> items) => BibleEquipmentWidget(
      items: items,
      noun: 'juego de lentes',
      feminine: false,
      pick: (context) =>
          pickBibleLensSet(context, db: db, projectId: projectId),
      onChanged: (next) {
        _saveValue(ref, OpticsPoints.kit, BibleEquipmentItem.encode(next));
        // El primer juego es el principal del proyecto; Formato lee de
        // aquí si es anamórfico y con qué factor.
        final main = next.isEmpty ? null : next.first;
        data
          ..primaryLensId = main?.catalogId
          ..opticType = main?.facts[OpticsPoints.factType] ?? data.opticType;
        _patchConfig({
          'lensSets': OpticsPoints.lensSetsFor(next),
          'primarySetName': main?.name ?? '',
        });
        onChanged(data);
      },
    );

    final kit = BiblePointPanel(
      label: label(OpticsPoints.kit, 'Juegos de lentes'),
      icon: Icons.camera_outlined,
      child: values.containsKey(OpticsPoints.kit)
          ? kitEditor(OpticsPoints.kitItems(values, config))
          // La lente principal de biblias anteriores, hasta que el punto
          // tenga su propio valor.
          : FutureBuilder<Lense?>(
              future: db.resolveProjectLens(projectId),
              builder: (context, snap) {
                final lens = snap.data;
                final set = lens == null
                    ? null
                    : BibleLensSet.group([lens]).first;
                return kitEditor(
                  OpticsPoints.kitItems(
                    values,
                    config,
                    legacyLensId: lens?.id,
                    legacyLensName: set?.name,
                    legacyFacts: set?.facts ?? const {},
                  ),
                );
              },
            ),
    );

    final philosophy = BiblePointPanel(
      label: label(OpticsPoints.philosophy, 'Filosofía de lentes'),
      icon: Icons.psychology_alt_outlined,
      child: BibleTextSpecsWidget(
        key: const ValueKey('optics_philosophy'),
        value: philosophyValue,
        hint:
            'Por qué estas lentes y este diafragma: qué carácter buscamos y '
            'qué evitamos…',
        onChanged: (value) {
          _saveValue(ref, OpticsPoints.philosophy, value.encode());
          data.lensPhilosophy = _orNull(value.text);
          String row(String name) => [
            for (final (label, text) in value.rows)
              if (label.trim().toLowerCase() == name.toLowerCase()) text.trim(),
          ].firstOrNull ?? '';
          _patchConfig({
            'tStop': row(OpticsPoints.rowTStop),
            'squeeze': row(OpticsPoints.rowSqueeze),
          });
          onChanged(data);
        },
      ),
    );

    final character = BiblePointPanel(
      label: label(OpticsPoints.character, 'Carácter óptico'),
      icon: Icons.blur_on,
      child: BibleCardsWidget(
        imageSource: imageSource,
        layout: BibleCardsLayout.columns,
        cards: characterCards,
        onChanged: (cards) => _saveValue(
          ref,
          OpticsPoints.character,
          BibleCard.encode(cards) ?? '[]',
        ),
      ),
    );

    final focals = BiblePointPanel(
      label: label(OpticsPoints.focals, 'Tabla de focales'),
      icon: Icons.table_rows_outlined,
      child: BibleTableWidget(
        key: const ValueKey('optics_focals'),
        value: focalsValue,
        onChanged: (value) {
          _saveValue(ref, OpticsPoints.focals, value.encode());
          data.primaryFocalLengths = OpticsPoints.focalNumbers(value);
          onChanged(data);
        },
      ),
    );

    final filtration = BiblePointPanel(
      label: label(OpticsPoints.filtration, 'Filtros'),
      icon: Icons.filter_tilt_shift,
      child: BibleMetersWidget(
        key: const ValueKey('optics_filtration'),
        meters: filtrationMeters,
        onChanged: (meters) => _saveValue(
          ref,
          OpticsPoints.filtration,
          BibleMeter.encode(meters) ?? '[]',
        ),
      ),
    );

    final maintenance = BiblePointPanel(
      label: label(OpticsPoints.maintenance, 'Revisión del juego'),
      icon: Icons.build_outlined,
      child: BibleTableWidget(
        key: const ValueKey('optics_maintenance'),
        value: maintenanceValue,
        onChanged: (value) =>
            _saveValue(ref, OpticsPoints.maintenance, value.encode()),
      ),
    );

    return BibleSectionScaffold(
      sectionId: _sectionId,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Por qué esta lente y este diafragma? Qué queremos contar con '
          'este carácter óptico…',
      sectionNumber: null,
      sectionTitle: 'Óptica',
      duplicateValues: {
        OpticsPoints.philosophy: philosophyValue.encode(),
        OpticsPoints.character: BibleCard.encode(characterCards),
        OpticsPoints.focals: focalsValue.encode(),
        OpticsPoints.filtration: BibleMeter.encode(filtrationMeters),
        OpticsPoints.maintenance: maintenanceValue.encode(),
      },
      fieldWidgets: {
        OpticsPoints.kit: kit,
        OpticsPoints.philosophy: philosophy,
        OpticsPoints.character: character,
        OpticsPoints.focals: focals,
        OpticsPoints.filtration: filtration,
        OpticsPoints.maintenance: maintenance,
      },
    );
  }
}
