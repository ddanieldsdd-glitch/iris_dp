import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../shared/visual_bible/bible_table.dart';
import '../../../../shared/visual_bible/color_points.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_color_blocks_widget.dart';
import '../bible_point_panel.dart';
import '../bible_table_widget.dart';
import 'section_scaffold.dart';

/// Color e imagen: con qué LUT se rueda, a qué temperatura y qué paleta
/// lleva cada bloque de la película.
///
/// Lo que guarda cada punto, y de dónde se lee lo escrito en biblias
/// anteriores, está en [ColorPoints].
class ColorImageSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final int bibleId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const ColorImageSection({
    super.key,
    required this.data,
    required this.projectId,
    required this.bibleId,
    this.sectionContentJson,
    required this.onChanged,
  });

  static const _sectionId = BibleSectionId.colorImage;

  Future<void> _saveValue(WidgetRef ref, String key, String? value) => ref
      .read(databaseProvider)
      .saveBibleSectionFieldValue(data.id, _sectionId, key, value);

  static String? _orNull(String text) =>
      text.trim().isEmpty ? null : text.trim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final blob = ColorPoints.blob(sectionContentJson);
    final values = BibleSectionFieldsConfig.parseValues(sectionContentJson);
    final labels = {
      for (final field in BibleSectionFieldsConfig.parse(
        sectionContentJson,
        _sectionId,
      ))
        field.key: field.label,
    };
    String label(String key, String fallback) => labels[key] ?? fallback;

    final lutValue = ColorPoints.lutValue(
      values,
      blob,
      workingLut: data.workingLutName,
      showLut: data.creativeLutName,
    );

    final lut = BiblePointPanel(
      label: label(ColorPoints.lut, 'LUT y ciencia de color'),
      icon: Icons.gradient_outlined,
      child: BibleTextSpecsWidget(
        key: const ValueKey('color_lut'),
        value: lutValue,
        hint:
            'Cómo se ve la imagen en el set y qué intención lleva el LUT: '
            'contraste, saturación, dominantes…',
        onChanged: (value) {
          _saveValue(ref, ColorPoints.lut, value.encode());
          // Cámara y Workflow leen estas columnas.
          data
            ..workingLutName = _orNull(
              ColorPoints.row(value, ColorPoints.rowWorkingLut),
            )
            ..creativeLutName = _orNull(
              ColorPoints.row(value, ColorPoints.rowShowLut),
            );
          onChanged(data);
        },
      ),
    );

    // La temperatura de antes podía venir del primer bloque de color.
    final baseTemp = BiblePointPanel(
      label: label(ColorPoints.baseTemp, 'Temperatura base'),
      icon: Icons.thermostat_outlined,
      child: StreamBuilder<List<VisualBibleColorBlock>>(
        stream: values.containsKey(ColorPoints.baseTemp)
            ? null
            : db.watchColorBlocksForBible(bibleId),
        builder: (context, snap) {
          final first = (snap.data ?? const <VisualBibleColorBlock>[])
              .firstOrNull;
          final meters = ColorPoints.baseTempMeters(
            values,
            blob,
            firstBlockKelvin: first?.colorTempKelvin,
          );
          return BibleMetersWidget(
            key: ValueKey('color_temp_${meters.firstOrNull?.value}'),
            meters: meters,
            onChanged: (next) => _saveValue(
              ref,
              ColorPoints.baseTemp,
              BibleMeter.encode(next) ?? '[]',
            ),
          );
        },
      ),
    );

    final blocks = BiblePointPanel(
      label: label(ColorPoints.blocks, 'Paletas por bloque'),
      icon: Icons.palette_outlined,
      child: BibleColorBlocksWidget(
        projectId: projectId,
        bibleId: bibleId,
        sectionId: _sectionId,
        legacyNames: ColorPoints.swatchNames(blob),
      ),
    );

    return BibleSectionScaffold(
      sectionId: _sectionId,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Qué emoción transmite esta paleta y este LUT? Cómo el color '
          'apoya la historia…',
      sectionNumber: null,
      sectionTitle: 'Color e imagen',
      duplicateValues: {ColorPoints.lut: lutValue.encode()},
      fieldWidgets: {
        ColorPoints.lut: lut,
        ColorPoints.baseTemp: baseTemp,
        ColorPoints.blocks: blocks,
      },
    );
  }
}
