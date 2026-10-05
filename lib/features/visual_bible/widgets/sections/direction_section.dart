import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../shared/visual_bible/bible_acts.dart';
import '../../../../shared/visual_bible/bible_cards.dart';
import '../../../../shared/visual_bible/bible_reference.dart';
import '../../../../shared/visual_bible/direction_points.dart';
import '../../bible_section_fields.dart';
import '../../moodboard_helpers.dart';
import '../../visual_bible_model.dart';
import '../bible_acts_widget.dart';
import '../bible_card_editor.dart';
import '../bible_cards_widget.dart';
import '../bible_form_widgets.dart';
import '../bible_navigation_scope.dart';
import '../bible_point_images.dart';
import '../bible_point_panel.dart';
import '../bible_references_deck.dart';
import 'section_scaffold.dart';

/// Dirección: de la idea al lenguaje, y las referencias al final.
///
/// Sus puntos se pintan con los widgets del catálogo (tarjetas, pilares,
/// actos, referencias). Lo que cada uno guarda está en [DirectionPoints].
class DirectionSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;

  /// Contenido de Concepto, para dar con los actos del proyecto en biblias
  /// anteriores a que fueran compartidos.
  final String? conceptSectionContentJson;
  final BibleChanged onChanged;

  const DirectionSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    this.conceptSectionContentJson,
    required this.onChanged,
  });

  static const _sectionId = BibleSectionId.direction;

  /// Datos de una sección que no son un punto: van juntos en un valor.
  static Map<String, dynamic> _blob(String? contentJson, String key) {
    final raw = BibleSectionFieldsConfig.parseValues(contentJson)[key];
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  Future<void> _saveValue(WidgetRef ref, String key, String value) => ref
      .read(databaseProvider)
      .saveBibleSectionFieldValue(data.id, _sectionId, key, value);

  /// Guarda las tarjetas de un punto. Una lista vacía se guarda como tal,
  /// para que no vuelva lo que había antes de pasar al catálogo.
  Future<void> _saveCards(WidgetRef ref, String key, List<BibleCard> cards) =>
      _saveValue(ref, key, BibleCard.encode(cards) ?? '[]');

  Future<void> _updateBlob(
    WidgetRef ref,
    Map<String, dynamic> blob,
    Map<String, dynamic> update,
  ) => _saveValue(ref, 'directionData', jsonEncode({...blob, ...update}));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blob = _blob(sectionContentJson, 'directionData');
    final values = BibleSectionFieldsConfig.parseValues(sectionContentJson);
    final labels = {
      for (final field in BibleSectionFieldsConfig.parse(
        sectionContentJson,
        _sectionId,
      ))
        field.key: field.label,
    };
    String label(String key, String fallback) => labels[key] ?? fallback;
    final imageSource = BibleCardImageSource(
      projectId: projectId,
      bibleId: data.id,
      sectionId: _sectionId,
    );

    final sharedActs = BibleSharedActs.resolve(
      data.actVisualNotes,
      directionBlob: blob,
      conceptBlob: _blob(conceptSectionContentJson, 'conceptData'),
    );
    final emotionTags = [
      if (blob['emotionTags'] is List)
        for (final tag in blob['emotionTags'] as List) tag.toString(),
    ];

    // Imágenes del moodboard que acompañan a un punto, bajo su panel.
    Widget withImages(String key, Widget panel) => data.id <= 0
        ? panel
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              panel,
              const SizedBox(height: 8),
              BiblePointImages(
                projectId: projectId,
                bibleId: data.id,
                sectionId: _sectionId,
                imageIds: biblePointImageIds(blob, key),
                onChanged: (ids) => _updateBlob(ref, blob, {
                  'pointImages': biblePointImagesWith(blob, key, ids),
                }),
              ),
            ],
          );

    final narrative = BiblePointPanel(
      label: label('narrative', 'Intención narrativa'),
      icon: Icons.psychology_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BibleTextField(
            label: '',
            hint: 'Qué cuenta la película y cómo debe sentirse la cámara…',
            maxLines: 5,
            initialValue: data.directionNarrativeIntent ?? '',
            onChanged: (v) {
              data.directionNarrativeIntent = v;
              onChanged(data);
            },
          ),
          const SizedBox(height: 12),
          BibleTagsWidget(
            tags: emotionTags,
            onChanged: (tags) => _updateBlob(ref, blob, {'emotionTags': tags}),
          ),
        ],
      ),
    );

    final tone = BiblePointPanel(
      label: label(DirectionPoints.tone, 'Tono y atmósfera'),
      icon: Icons.blur_on,
      child: BibleCardsWidget(
        imageSource: imageSource,
        cards: DirectionPoints.toneCards(values, blob, legacyTone: data.tone),
        onChanged: (cards) => _saveCards(ref, DirectionPoints.tone, cards),
      ),
    );

    final strategies = BiblePointPanel(
      label: label(DirectionPoints.strategies, 'Estrategia visual'),
      icon: Icons.view_week_outlined,
      child: BibleCardsWidget(
        imageSource: imageSource,
        layout: BibleCardsLayout.columns,
        cards: DirectionPoints.strategyCards(
          values,
          blob,
          camera: data.cameraPhilosophy,
          staging: data.stagingApproach,
          pointOfView: data.pointOfView,
        ),
        onChanged: (cards) {
          _saveCards(ref, DirectionPoints.strategies, cards);
          // Cámara y el resumen del proyecto leen estas columnas.
          data
            ..cameraPhilosophy = DirectionPoints.pillarBody(
              cards,
              DirectionPoints.pillarCamera,
            )
            ..stagingApproach = DirectionPoints.pillarBody(
              cards,
              DirectionPoints.pillarStaging,
            )
            ..pointOfView = DirectionPoints.pillarBody(
              cards,
              DirectionPoints.pillarPov,
            );
          onChanged(data);
        },
      ),
    );

    final acts = BiblePointPanel(
      label: label(DirectionPoints.acts, 'Intención por acto'),
      icon: Icons.movie_filter_outlined,
      child: BibleActsPoint(
        projectId: projectId,
        bibleId: data.id,
        sectionId: _sectionId,
        value: DirectionPoints.actsValue(values, blob),
        onChanged: (value) =>
            _saveValue(ref, DirectionPoints.acts, value.encode()),
        sharedActs: sharedActs,
        onSharedActsChanged: (next) {
          data.actVisualNotes = BibleSharedActs.encode(next);
          onChanged(data);
        },
      ),
    );

    final transitions = BiblePointPanel(
      label: label(DirectionPoints.transitions, 'Lenguaje de transiciones'),
      icon: Icons.animation,
      child: BibleCardsWidget(
        imageSource: imageSource,
        cards: DirectionPoints.transitionCards(values, blob),
        onChanged: (cards) =>
            _saveCards(ref, DirectionPoints.transitions, cards),
      ),
    );

    final references = BiblePointPanel(
      label: label('references', 'Referencias de dirección'),
      icon: Icons.collections_outlined,
      child: BibleReferencesDeck(
        projectId: projectId,
        bibleId: data.id,
        sectionId: _sectionId,
        kinds: kDirectionReferenceKinds,
        copy: BibleReferencesCopy.direction,
        references: BibleReference.listFrom(blob['refsMetadata']),
        onChanged: (next) => _updateBlob(ref, blob, {
          'refsMetadata': [for (final r in next) r.toJson()],
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
      narrativeHint:
          '¿Cuál es la intención global de la fotografía respecto a la historia?',
      sectionNumber: null,
      sectionTitle: 'Dirección',
      sharedActs: sharedActs,
      fieldWidgets: {
        'narrative': narrative,
        DirectionPoints.tone: withImages(DirectionPoints.tone, tone),
        DirectionPoints.strategies: withImages(
          DirectionPoints.strategies,
          strategies,
        ),
        // Las imágenes sueltas que tuviera el punto antes de que cada acto
        // llevara las suyas.
        DirectionPoints.acts:
            biblePointImageIds(blob, DirectionPoints.acts).isEmpty
            ? acts
            : withImages(DirectionPoints.acts, acts),
        DirectionPoints.transitions: withImages(
          DirectionPoints.transitions,
          transitions,
        ),
        if (data.id > 0) 'references': references,
      },
    );
  }
}
