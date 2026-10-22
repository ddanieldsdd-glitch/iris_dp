import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/visual_bible/bible_cards.dart';
import '../../../../shared/visual_bible/bible_table.dart';
import '../../../../shared/visual_bible/exposure_points.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_card_editor.dart';
import '../bible_cards_widget.dart';
import '../bible_form_widgets.dart';
import '../bible_point_panel.dart';
import '../bible_table_widget.dart';
import 'section_scaffold.dart';

/// Exposición: a qué se expone, cómo se protege la imagen y qué cambia en
/// cada bloque y en cada localización.
///
/// Sus puntos se pintan con los widgets del catálogo. Lo que cada uno
/// guarda, y de dónde se lee lo escrito en biblias anteriores, está en
/// [ExposurePoints].
class ExposureSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final int bibleId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const ExposureSection({
    super.key,
    required this.data,
    required this.projectId,
    required this.bibleId,
    this.sectionContentJson,
    required this.onChanged,
  });

  static const _sectionId = BibleSectionId.exposure;

  Future<void> _saveValue(WidgetRef ref, String key, String? value) => ref
      .read(databaseProvider)
      .saveBibleSectionFieldValue(data.id, _sectionId, key, value);

  static String? _orNull(String text) =>
      text.trim().isEmpty ? null : text.trim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final palette = context.palette;
    final blob = ExposurePoints.blob(sectionContentJson);
    final values = BibleSectionFieldsConfig.parseValues(sectionContentJson);
    final labels = {
      for (final field in BibleSectionFieldsConfig.parse(
        sectionContentJson,
        _sectionId,
      ))
        field.key: field.label,
    };
    String label(String key, String fallback) => labels[key] ?? fallback;

    final globalValue = ExposurePoints.globalValue(
      values,
      blob,
      defaultTStop: data.defaultTStop,
      ndNotes: data.ndNotes,
      highlightBehavior: data.highlightBehavior,
      shadowBehavior: data.shadowBehavior,
    );
    final chainCards = ExposurePoints.chainCards(values, blob);
    final signalMeters = ExposurePoints.signalMeters(values, blob);
    final imageSource = BibleCardImageSource(
      projectId: projectId,
      bibleId: data.id,
      sectionId: _sectionId,
    );

    final narrative = BiblePointPanel(
      label: label('narrative', 'Intención narrativa'),
      icon: Icons.psychology_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BibleTextField(
            label: '',
            hint:
                '¿Protegemos las altas luces o dejamos quemar? ¿Por qué? '
                'Cómo la exposición refuerza la historia…',
            maxLines: 5,
            initialValue: ExposurePoints.narrative(
              blob,
              data.exposureNarrativeIntent,
            ),
            onChanged: (v) {
              data.exposureNarrativeIntent = _orNull(v);
              onChanged(data);
            },
          ),
          const SizedBox(height: 12),
          BibleTagsWidget(
            tags: ExposurePoints.intentTags(blob),
            onChanged: (tags) => _saveValue(
              ref,
              'exposureData',
              jsonEncode({...blob, 'intentTags': tags}),
            ),
          ),
        ],
      ),
    );

    final global = BiblePointPanel(
      label: label(ExposurePoints.global, 'Exposición de trabajo'),
      icon: Icons.exposure_outlined,
      child: BibleTextSpecsWidget(
        key: const ValueKey('exposure_global'),
        value: globalValue,
        // El ISO nativo de la cámara, mientras no se escriba otro.
        placeholders: {
          if (data.nativeIso != null) ExposurePoints.rowIso: '${data.nativeIso}',
        },
        hint: 'A qué se expone por norma y cuándo se rompe la norma…',
        onChanged: (value) {
          _saveValue(ref, ExposurePoints.global, value.encode());
          // Columnas que leen la planta, Iluminación y el resumen.
          data
            ..defaultTStop = _orNull(
              ExposurePoints.row(value, ExposurePoints.rowTStop),
            )
            ..ndNotes = _orNull(ExposurePoints.row(value, ExposurePoints.rowNd))
            ..highlightBehavior = _orNull(
              ExposurePoints.row(value, ExposurePoints.rowHighlights),
            )
            ..shadowBehavior = _orNull(
              ExposurePoints.row(value, ExposurePoints.rowShadows),
            );
          onChanged(data);
        },
      ),
    );

    final chain = BiblePointPanel(
      label: label(ExposurePoints.chain, 'Cadena de exposición'),
      icon: Icons.linear_scale,
      child: BibleCardsWidget(
        imageSource: imageSource,
        layout: BibleCardsLayout.columns,
        cards: chainCards,
        onChanged: (cards) => _saveValue(
          ref,
          ExposurePoints.chain,
          BibleCard.encode(cards) ?? '[]',
        ),
      ),
    );

    final signal = BiblePointPanel(
      label: label(ExposurePoints.signal, 'Niveles de señal'),
      icon: Icons.show_chart,
      child: BibleMetersWidget(
        key: const ValueKey('exposure_signal'),
        meters: signalMeters,
        onChanged: (meters) => _saveValue(
          ref,
          ExposurePoints.signal,
          BibleMeter.encode(meters) ?? '[]',
        ),
      ),
    );

    // Los bloques de antes vivían en su propia tabla de la base.
    final blocks = BiblePointPanel(
      label: label(ExposurePoints.blocks, 'Bloques de exposición'),
      icon: Icons.view_agenda_outlined,
      child: StreamBuilder<List<ExposureBlock>>(
        stream: values.containsKey(ExposurePoints.blocks)
            ? null
            : db.watchExposureBlocksForBible(bibleId),
        builder: (context, snap) {
          final table = ExposurePoints.blocksValue(values, [
            for (final b in snap.data ?? const <ExposureBlock>[])
              (
                name: b.blockName,
                intent: b.narrativeIntent,
                keyFill: b.keyFillRatio,
                highlights: b.highlightStrategy,
                shadows: b.shadowStrategy,
              ),
          ]);
          return BibleTableWidget(
            key: ValueKey('exposure_blocks_${table.rows.length}'),
            value: table,
            onChanged: (value) =>
                _saveValue(ref, ExposurePoints.blocks, value.encode()),
          );
        },
      ),
    );

    final byLocation = BiblePointPanel(
      label: label(ExposurePoints.byLocation, 'Exposición por localización'),
      icon: Icons.place_outlined,
      child: StreamBuilder<List<LocationBasePlan>>(
        stream: db.watchLocationsForProject(projectId),
        builder: (context, snap) {
          final plans = snap.data ?? const <LocationBasePlan>[];
          final table = ExposurePoints.byLocationValue(
            values,
            blob,
            setNames: {for (final p in plans) p.id: p.locationName},
          );
          final names = [for (final p in plans) p.locationName];
          final missing = ExposurePoints.withLocations(table, names);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BibleTableWidget(
                key: ValueKey('exposure_locations_${table.rows.length}'),
                value: table,
                onChanged: (value) => _saveValue(
                  ref,
                  ExposurePoints.byLocation,
                  value.encode(),
                ),
              ),
              if (missing.rows.length > table.rows.length)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _saveValue(
                      ref,
                      ExposurePoints.byLocation,
                      missing.encode(),
                    ),
                    icon: Icon(
                      Icons.playlist_add,
                      size: 16,
                      color: palette.textSecondary,
                    ),
                    label: Text(
                      'AÑADIR LAS LOCALIZACIONES DEL PROYECTO '
                      '(${missing.rows.length - table.rows.length})',
                      style: BiblePointPanel.labelStyle(palette),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    return BibleSectionScaffold(
      sectionId: _sectionId,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Protegemos las altas luces o dejamos quemar? ¿Por qué?',
      sectionNumber: null,
      sectionTitle: 'Exposición',
      duplicateValues: {
        ExposurePoints.global: globalValue.encode(),
        ExposurePoints.chain: BibleCard.encode(chainCards),
        ExposurePoints.signal: BibleMeter.encode(signalMeters),
      },
      fieldWidgets: {
        'narrative': narrative,
        ExposurePoints.global: global,
        ExposurePoints.chain: chain,
        ExposurePoints.signal: signal,
        ExposurePoints.blocks: blocks,
        ExposurePoints.byLocation: byLocation,
      },
    );
  }
}
