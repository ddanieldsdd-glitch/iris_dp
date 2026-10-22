import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../shared/visual_bible/bible_table.dart';
import '../../../../shared/visual_bible/texture_points.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_point_images.dart';
import '../bible_point_panel.dart';
import '../bible_table_widget.dart';
import 'section_scaffold.dart';

/// Textura: qué grano, qué difusión y cuánto ruido se acepta.
///
/// Sus puntos se pintan con los widgets del catálogo. Lo que cada uno
/// guarda, y de dónde se lee lo escrito en biblias anteriores, está en
/// [TexturePoints].
class TextureSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const TextureSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    required this.onChanged,
  });

  static const _sectionId = BibleSectionId.texture;

  Future<void> _saveValue(WidgetRef ref, String key, String? value) => ref
      .read(databaseProvider)
      .saveBibleSectionFieldValue(data.id, _sectionId, key, value);

  static String? _orNull(String text) =>
      text.trim().isEmpty ? null : text.trim();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blob = TexturePoints.blob(sectionContentJson);
    final values = BibleSectionFieldsConfig.parseValues(sectionContentJson);
    final labels = {
      for (final field in BibleSectionFieldsConfig.parse(
        sectionContentJson,
        _sectionId,
      ))
        field.key: field.label,
    };
    String label(String key, String fallback) => labels[key] ?? fallback;

    final grainValue = TexturePoints.grainValue(
      values,
      blob,
      grainLevel: data.grainLevel,
    );
    final diffusionMeters = TexturePoints.diffusionMeters(
      values,
      blob,
      diffusionNotes: data.diffusionNotes,
    );
    final noiseValue = TexturePoints.noiseValue(
      values,
      blob,
      highlightBehavior: data.highlightBehavior,
      shadowBehavior: data.shadowBehavior,
    );
    final comparisonIds = [
      for (final id in BibleSectionPointValue.decodeList(
        values[TexturePoints.comparison],
      ))
        if (int.tryParse(id) != null) int.parse(id),
    ];

    // Dos o más imágenes lado a lado: con grano y sin él, con filtro y sin
    // él, la referencia y la prueba…
    final comparison = BiblePointPanel(
      label: label(TexturePoints.comparison, 'Comparación de textura'),
      icon: Icons.compare_outlined,
      child: BiblePointImages(
        projectId: projectId,
        bibleId: data.id,
        sectionId: _sectionId,
        imageIds: comparisonIds,
        height: 220,
        onChanged: (next) => _saveValue(
          ref,
          TexturePoints.comparison,
          BibleSectionPointValue.encodeList([for (final id in next) '$id']),
        ),
      ),
    );

    final grain = BiblePointPanel(
      label: label(TexturePoints.grain, 'Grano'),
      icon: Icons.grain,
      child: BibleTextSpecsWidget(
        key: const ValueKey('texture_grain'),
        value: grainValue,
        hint: 'Qué grano queremos y por qué: fino, visible, de color…',
        onChanged: (value) {
          _saveValue(ref, TexturePoints.grain, value.encode());
          // Columnas que leen Concepto y el resumen del proyecto.
          final rows = [
            for (final (_, text) in value.rows)
              if (text.trim().isNotEmpty) text.trim(),
          ];
          data
            ..grainLevel = _orNull(
              TexturePoints.row(value, TexturePoints.rowEmulation),
            )
            ..imageTexture = _orNull(rows.join(' · '));
          onChanged(data);
        },
      ),
    );

    final diffusion = BiblePointPanel(
      label: label(TexturePoints.diffusion, 'Difusión'),
      icon: Icons.blur_on,
      child: BibleMetersWidget(
        key: const ValueKey('texture_diffusion'),
        meters: diffusionMeters,
        onChanged: (meters) {
          _saveValue(
            ref,
            TexturePoints.diffusion,
            BibleMeter.encode(meters) ?? '[]',
          );
          data.diffusionNotes = _orNull(
            TexturePoints.diffusionSummary(meters),
          );
          onChanged(data);
        },
      ),
    );

    final noise = BiblePointPanel(
      label: label(TexturePoints.noise, 'Ruido del sensor'),
      icon: Icons.memory_outlined,
      child: BibleTextSpecsWidget(
        key: const ValueKey('texture_noise'),
        value: noiseValue,
        hint:
            'Cuánto ruido se acepta, a qué ISO aparece y cómo se comportan '
            'las sombras…',
        onChanged: (value) {
          _saveValue(ref, TexturePoints.noise, value.encode());
          final rows = [
            for (final (name, text) in value.rows.take(3))
              if (text.trim().isNotEmpty) '$name: ${text.trim()}',
          ];
          data
            ..sensorShadowBehavior = _orNull(rows.join(' · '))
            ..highlightBehavior = _orNull(
              TexturePoints.row(value, TexturePoints.rowHighlights),
            )
            ..shadowBehavior = _orNull(
              TexturePoints.row(value, TexturePoints.rowShadows),
            );
          onChanged(data);
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
          '¿Qué textura tiene la imagen y qué le hace sentir al espectador?',
      sectionNumber: null,
      sectionTitle: 'Textura',
      duplicateValues: {
        TexturePoints.grain: grainValue.encode(),
        TexturePoints.diffusion: BibleMeter.encode(diffusionMeters),
        TexturePoints.noise: noiseValue.encode(),
      },
      fieldWidgets: {
        if (data.id > 0) TexturePoints.comparison: comparison,
        TexturePoints.grain: grain,
        TexturePoints.diffusion: diffusion,
        TexturePoints.noise: noise,
      },
    );
  }
}
