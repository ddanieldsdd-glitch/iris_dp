import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../shared/visual_bible/bible_section_fields.dart';
import 'bible_blueprint.dart';
import 'bible_section_style_store.dart';

/// Tres pantallas de ejemplo (una por estilo) para demostrar capacidades.
abstract final class BibleStyleShowcase {
  static const cinematicId = 'example_cinematic';
  static const technicalId = 'example_technical';
  static const minimalistId = 'example_minimalist';

  static const allIds = {cinematicId, technicalId, minimalistId};

  static List<BibleShowcaseSpec> get specs => const [
        BibleShowcaseSpec(
          id: cinematicId,
          label: 'Ejemplo · Cinematic',
          style: BibleSectionStyle.cinematic,
          groupId: 'narrative',
          iconKey: 'movie',
          description:
              'Narrativa, atmósfera y refs moodboard. Ideal para dirección y look.',
        ),
        BibleShowcaseSpec(
          id: technicalId,
          label: 'Ejemplo · Technical',
          style: BibleSectionStyle.technical,
          groupId: 'technical',
          iconKey: 'camera',
          description:
              'Specs, métricas y notas de rodaje. Ideal para cámara, óptica y exposición.',
        ),
        BibleShowcaseSpec(
          id: minimalistId,
          label: 'Ejemplo · Minimalist',
          style: BibleSectionStyle.minimalist,
          groupId: 'operational',
          iconKey: 'notes',
          description:
              'Solo lo esencial: intención, notas e imagen. Ideal para briefs rápidos.',
        ),
      ];

  static Map<String, String> _sampleValues(BibleSectionStyle style) =>
      switch (style) {
        BibleSectionStyle.cinematic => {
            'narrative':
                'La imagen debe sentir humedad y secreto: negros profundos, '
                'un solo eje de luz y caras que emergen del vacío. El ritmo '
                'es lento; el corte solo llega cuando la emoción lo pide.',
            'atmosphere':
                'Contraste alto · cyan en sombras · ámbar en piel · grain '
                'fino tipo 500T · difusión 1/8 Black Pro-Mist.',
            'body':
                'Escenas clave: (1) entrada al portal — contraluz, silueta; '
                '(2) confesión — close 85mm, shallow DOF; (3) huida — handheld '
                'nervioso, available sodium. Cada bloque refuerza con stills '
                'del moodboard y una nota de intención bajo la imagen.',
          },
        BibleSectionStyle.technical => {
            'narrative':
                'Prioridad: latitud en sombras y skin consistente bajo LED '
                'bicolor. Evitar clipping en practicals de ventana.',
            'specs':
                'Cámara: Alexa 35 · ARRIRAW 4.6K · EI 800\n'
                'Óptica: Signature Prime 35/47/75 · T1.8\n'
                'Exposición: key 1.5–2 stops under mid-grey · ratio 4:1 noche\n'
                'WB: 4300K + ¼ CTO en practicals · gel CTB en LED fill',
            'notes':
                'Checklist: false color skin 40–50 IRE · waveform 70 IRE max '
                'en highlights · LUT de monitor Rec.709 preview · ND 0.6 en '
                'día para T2.8. Documentar cada setup en el bloque de exposición.',
          },
        BibleSectionStyle.minimalist => {
            'narrative':
                'Una idea: intimidad bajo luz disponible. Sin adornos.',
            'body':
                'Solo tres stills de referencia y una frase de intención. '
                'Si no cabe en este bloque, no entra en el look.',
          },
      };

  static String contentJsonFor(BibleSectionStyle style, String label) {
    final fields = BibleSectionFieldsConfig.packForStyle(
      style.storageKey,
      sectionLabel: label,
    );
    return BibleSectionFieldsConfig.encode(
      fields,
      values: _sampleValues(style),
    );
  }

  /// Inserta o actualiza las 3 pantallas de ejemplo en la biblia.
  static Future<int> install({
    required AppDatabase db,
    required int bibleId,
    required int projectId,
  }) async {
    final groups = await db.watchBibleSectionGroups(bibleId).first;
    var created = 0;

    for (final spec in specs) {
      final groupId = groups.any((g) => g.id == spec.groupId)
          ? spec.groupId
          : (groups.isNotEmpty ? groups.first.id : 'narrative');

      final existing = await (db.select(db.bibleSectionDefinitions)
            ..where(
              (d) => d.bibleId.equals(bibleId) & d.id.equals(spec.id),
            ))
          .getSingleOrNull();

      final content = contentJsonFor(spec.style, spec.label);

      if (existing == null) {
        final defs = await (db.select(db.bibleSectionDefinitions)
              ..where(
                (d) =>
                    d.bibleId.equals(bibleId) & d.groupId.equals(groupId),
              ))
            .get();
        final maxOrder = defs.isEmpty
            ? 0
            : defs.map((d) => d.sortOrder).reduce((a, b) => a > b ? a : b);

        await db.into(db.bibleSectionDefinitions).insert(
              BibleSectionDefinitionsCompanion.insert(
                id: spec.id,
                bibleId: bibleId,
                groupId: groupId,
                label: spec.label,
                sortOrder: Value(maxOrder + 1),
                isBuiltIn: const Value(false),
                template: const Value('freeform'),
                iconKey: Value(spec.iconKey),
                contentJson: Value(content),
              ),
            );
        created++;
      } else {
        await db.upsertBibleSectionDefinition(
          existing.copyWith(
            label: spec.label,
            contentJson: Value(content),
            isHidden: false,
            template: 'freeform',
          ),
        );
      }

      await BibleSectionStyleStore.save(projectId, spec.id, spec.style);
    }

    return created;
  }

  static Future<void> remove({
    required AppDatabase db,
    required int bibleId,
  }) async {
    for (final id in allIds) {
      await db.deleteCustomBibleSection(bibleId: bibleId, sectionId: id);
    }
  }
}

class BibleShowcaseSpec {
  final String id;
  final String label;
  final BibleSectionStyle style;
  final String groupId;
  final String iconKey;
  final String description;

  const BibleShowcaseSpec({
    required this.id,
    required this.label,
    required this.style,
    required this.groupId,
    required this.iconKey,
    required this.description,
  });
}
