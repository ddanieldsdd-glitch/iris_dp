import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../shared/visual_bible/bible_acts.dart';
import '../../../../shared/visual_bible/bible_reference.dart';
import '../../../../shared/visual_bible/bible_text_specs.dart';
import '../../../../shared/visual_bible/concept_points.dart';
import '../../bible_section_fields.dart';
import '../../moodboard_helpers.dart';
import '../../visual_bible_model.dart';
import '../bible_acts_widget.dart';
import '../bible_cards_widget.dart';
import '../bible_form_widgets.dart';
import '../bible_navigation_scope.dart';
import '../bible_palette_widget.dart';
import '../bible_point_images.dart';
import '../bible_point_panel.dart';
import '../bible_references_deck.dart';
import '../bible_table_widget.dart';
import 'section_scaffold.dart';

/// Concepto de imagen: de la intención a la luz, el color, la composición y
/// las referencias.
///
/// Sus puntos se pintan con los widgets del catálogo. Lo que cada uno
/// guarda, y de dónde se lee lo escrito en biblias anteriores, está en
/// [ConceptPoints].
class ConceptSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final String? formatSectionContentJson;
  final BibleChanged onChanged;

  const ConceptSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    this.formatSectionContentJson,
    required this.onChanged,
  });

  static const _sectionId = BibleSectionId.concept;

  static Map<String, dynamic> _blob(String? contentJson) {
    final raw = BibleSectionFieldsConfig.parseValues(contentJson)['conceptData'];
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  Future<void> _saveValue(WidgetRef ref, String key, String? value) => ref
      .read(databaseProvider)
      .saveBibleSectionFieldValue(data.id, _sectionId, key, value);

  Future<void> _updateBlob(
    WidgetRef ref,
    Map<String, dynamic> blob,
    Map<String, dynamic> update,
  ) => _saveValue(ref, 'conceptData', jsonEncode({...blob, ...update}));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blob = _blob(sectionContentJson);
    final values = BibleSectionFieldsConfig.parseValues(sectionContentJson);
    final labels = {
      for (final field in BibleSectionFieldsConfig.parse(
        sectionContentJson,
        _sectionId,
      ))
        field.key: field.label,
    };
    String label(String key, String fallback) => labels[key] ?? fallback;

    final sharedActs = BibleSharedActs.resolve(
      data.actVisualNotes,
      conceptBlob: blob,
    );
    final paletteValue = ConceptPoints.paletteValue(values, blob);
    final symbolismValue = ConceptPoints.symbolismValue(values, blob);
    final lightValue = ConceptPoints.lightValue(
      values,
      blob,
      philosophy: data.lightingPhilosophy,
      contrast: data.contrastStyle,
    );
    final compositionValue = ConceptPoints.compositionValue(values, blob);
    final actsValue = ConceptPoints.actsValue(values, blob);
    final actCompositionRows = ConceptPoints.actCompositionRows(blob);
    final (keyFrameTitle, keyFrameTech) = ConceptPoints.keyFrameOf(blob);

    final narrative = BiblePointPanel(
      label: label('narrative', 'Intención narrativa'),
      icon: Icons.psychology_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BibleTextField(
            label: '',
            hint: '¿Qué debe sentir el ojo del espectador en cada acto?',
            maxLines: 5,
            initialValue: data.narrativeIntentForSection(_sectionId) ?? '',
            onChanged: (v) {
              data.setNarrativeIntentForSection(
                _sectionId,
                v.trim().isEmpty ? null : v.trim(),
              );
              onChanged(data);
            },
          ),
          const SizedBox(height: 12),
          // Atmósfera visual: tres o cuatro palabras que la resumen.
          BibleTagsWidget(
            tags: ConceptPoints.atmosphereTags(blob),
            onChanged: (tags) => _updateBlob(ref, blob, {
              'atmosphereTags': tags,
            }),
          ),
        ],
      ),
    );

    final light = BiblePointPanel(
      label: label(ConceptPoints.light, 'Filosofía de luz'),
      icon: Icons.lightbulb_outline,
      child: BibleTextSpecsWidget(
        key: const ValueKey('concept_light'),
        value: lightValue,
        hint: 'De dónde viene la luz y qué cuenta: motivada, dura, lateral…',
        onChanged: (value) {
          _saveValue(ref, ConceptPoints.light, value.encode());
          // Iluminación y el resumen del proyecto leen estas columnas.
          data.lightingPhilosophy = value.text.trim().isEmpty
              ? null
              : value.text.trim();
          onChanged(data);
        },
      ),
    );

    final shadows = BiblePointPanel(
      label: label(ConceptPoints.shadows, 'Tratamiento de sombras'),
      icon: Icons.contrast,
      child: BibleTextField(
        label: '',
        hint: 'Cuánto se ve en la sombra, con qué densidad y qué color…',
        maxLines: 5,
        initialValue: ConceptPoints.shadowsText(values, blob),
        onChanged: (v) => _saveValue(ref, ConceptPoints.shadows, v),
      ),
    );

    final palettePoint = BiblePalettePoint(
      projectId: projectId,
      bibleId: data.id,
      sectionId: _sectionId,
      label: label(ConceptPoints.palette, 'Paleta maestra'),
      icon: Icons.palette_outlined,
      value: paletteValue,
      onChanged: (value) =>
          _saveValue(ref, ConceptPoints.palette, value.encode()),
    );

    final symbolism = BiblePalettePoint(
      projectId: projectId,
      bibleId: data.id,
      sectionId: _sectionId,
      label: label(ConceptPoints.symbolism, 'Simbología de color'),
      icon: Icons.color_lens_outlined,
      symbolism: true,
      value: symbolismValue,
      onChanged: (value) =>
          _saveValue(ref, ConceptPoints.symbolism, value.encode()),
    );

    final composition = BiblePointPanel(
      label: label(ConceptPoints.composition, 'Composición'),
      icon: Icons.grid_on_outlined,
      child: BibleTextSpecsWidget(
        key: const ValueKey('concept_composition'),
        value: compositionValue,
        hint:
            'Cómo se ordena el cuadro: simetría, espacio negativo, líneas, '
            'relación del personaje con el entorno…',
        onChanged: (value) =>
            _saveValue(ref, ConceptPoints.composition, value.encode()),
      ),
    );

    final acts = BiblePointPanel(
      label: label(ConceptPoints.acts, 'Intención visual por acto'),
      icon: Icons.movie_filter_outlined,
      child: BibleActsPoint(
        projectId: projectId,
        bibleId: data.id,
        sectionId: _sectionId,
        value: actsValue,
        onChanged: (value) =>
            _saveValue(ref, ConceptPoints.acts, value.encode()),
        sharedActs: sharedActs,
        onSharedActsChanged: (next) {
          data.actVisualNotes = BibleSharedActs.encode(next);
          onChanged(data);
        },
      ),
    );

    // Puntos de biblias anteriores: se enseñan solo si el usuario los
    // conserva en su pantalla, con lo que tuviera escrito.
    final actComposition = BiblePointPanel(
      label: label(ConceptPoints.actComposition, 'Composición por actos'),
      icon: Icons.grid_view_outlined,
      child: BibleTextSpecsWidget(
        key: const ValueKey('concept_act_composition'),
        value: values.containsKey(ConceptPoints.actComposition)
            ? BibleTextSpecsValue.decode(values[ConceptPoints.actComposition])
            : BibleTextSpecsValue(rows: actCompositionRows),
        onChanged: (value) =>
            _saveValue(ref, ConceptPoints.actComposition, value.encode()),
      ),
    );

    final keyFrame = BiblePointPanel(
      label: label(ConceptPoints.keyFrame, 'Key Frame'),
      icon: Icons.movie_filter_outlined,
      child: BibleTextSpecsWidget(
        key: const ValueKey('concept_key_frame'),
        value: values.containsKey(ConceptPoints.keyFrame)
            ? BibleTextSpecsValue.decode(values[ConceptPoints.keyFrame])
            : BibleTextSpecsValue(
                text: [
                  keyFrameTitle,
                  keyFrameTech,
                ].where((e) => e.isNotEmpty).join('\n'),
              ),
        hint: 'El fotograma que resume la película: qué se ve y por qué.',
        onChanged: (value) =>
            _saveValue(ref, ConceptPoints.keyFrame, value.encode()),
      ),
    );

    final references = BiblePointPanel(
      label: label('references', 'Referencias visuales'),
      icon: Icons.collections_outlined,
      child: BibleReferencesDeck(
        projectId: projectId,
        bibleId: data.id,
        sectionId: _sectionId,
        kinds: kConceptReferenceKinds,
        copy: BibleReferencesCopy.concept,
        references: BibleReference.listFrom(blob['keyReferences']),
        onChanged: (next) => _updateBlob(ref, blob, {
          'keyReferences': [for (final r in next) r.toJson()],
        }),
        onAddImage: () => MoodboardHelpers.addManualImages(
          db: ref.read(databaseProvider),
          projectId: projectId,
          bibleId: data.id,
          assignedSections: const [_sectionId],
        ),
        onOpenMoodboard: () =>
            BibleNavigationScope.openMoodboardForSection(context, _sectionId),
      ),
    );

    return BibleSectionScaffold(
      sectionId: _sectionId,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint: '¿Qué debe sentir el ojo del espectador en cada acto?',
      sectionNumber: null,
      sectionTitle: 'Concepto de imagen',
      sharedActs: sharedActs,
      duplicateValues: {
        ConceptPoints.palette: paletteValue.encode(),
        ConceptPoints.symbolism: symbolismValue.encode(),
        ConceptPoints.light: lightValue.encode(),
        ConceptPoints.composition: compositionValue.encode(),
        ConceptPoints.acts: actsValue.encode(),
      },
      legacyPointImages: {
        for (final key in const [
          ConceptPoints.palette,
          ConceptPoints.symbolism,
          ConceptPoints.light,
          ConceptPoints.shadows,
          ConceptPoints.composition,
        ])
          key: biblePointImageIds(blob, key),
      },
      fieldWidgets: {
        'narrative': narrative,
        ConceptPoints.light: light,
        ConceptPoints.shadows: shadows,
        ConceptPoints.palette: palettePoint,
        ConceptPoints.symbolism: symbolism,
        ConceptPoints.composition: composition,
        ConceptPoints.acts: acts,
        ConceptPoints.actComposition: actComposition,
        ConceptPoints.keyFrame: keyFrame,
        if (data.id > 0) 'references': references,
      },
    );
  }
}
