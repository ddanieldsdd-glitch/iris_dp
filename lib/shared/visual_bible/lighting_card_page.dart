import 'dart:convert';

import 'bible_cards.dart';
import 'bible_palette.dart';
import 'bible_section_fields.dart';
import 'lighting_metrics.dart';
import 'narrative_card_kind.dart';

/// Los puntos de una ficha de Iluminación (una idea de luz, la luz de un
/// set o una referencia de cine) y lo que tiene escrito en cada uno.
///
/// Se guarda en `metaJson['page']` de la ficha. Una ficha que aún no la
/// tiene nace con la plantilla de su tipo, rellena con lo que la ficha ya
/// tenía antes (texto, imágenes, métricas, paleta, sub-puntos y bloques de
/// refuerzo): nada se pierde al pasar a este formato.
class LightingCardPage {
  final List<BibleSectionField> fields;
  final Map<String, String> values;

  const LightingCardPage({required this.fields, required this.values});

  // Claves de los puntos de plantilla.
  static const main = 'main';
  static const light = 'light';
  static const mosaic = 'mosaic';
  static const palette = 'palette';
  static const how = 'how';
  static const where = 'where';
  static const day = 'day';
  static const night = 'night';
  static const sources = 'sources';
  static const problems = 'problems';
  static const film = 'film';
  static const take = 'take';

  /// El primer texto de la ficha es su cuerpo: lo leen las tarjetas, el
  /// PDF y la nota de la localización.
  static const bodyKey = main;

  static BibleSectionField _f(
    String key,
    String label, {
    BibleSectionFieldType type = BibleSectionFieldType.text,
    String? widget,
    String? hint,
    BiblePointWidth width = BiblePointWidth.full,
  }) => BibleSectionField(
    key: key,
    label: label,
    type: type,
    widget: widget,
    hint: hint,
    width: width,
  );

  static BibleSectionField _light(String label) => _f(
    light,
    label,
    type: BibleSectionFieldType.specs,
    widget: 'light_metrics',
  );

  static BibleSectionField _mosaic(String label) => _f(
    mosaic,
    label,
    type: BibleSectionFieldType.cards,
    widget: 'cards_mosaic',
  );

  static BibleSectionField _palette(String label) => _f(
    palette,
    label,
    type: BibleSectionFieldType.palette,
    widget: 'palette',
  );

  /// Plantilla de puntos con la que nace cada tipo de ficha. [stills]: la
  /// referencia de cine es un grupo de imágenes, no una película.
  static List<BibleSectionField> template(String kind, {bool stills = false}) =>
      switch (kind) {
        NarrativeCardKind.locationLight => [
          _mosaic('Cómo la imaginamos'),
          _f(
            main,
            'La luz del lugar',
            hint:
                'Qué luz tiene este lugar en la película y por qué: de dónde '
                'viene, qué deja en sombra, qué se aprovecha de lo que hay…',
          ),
          _light('Luz: color y contraste'),
          _f(
            day,
            'De día',
            hint: 'Cómo entra el sol, a qué horas sirve, qué se corrige…',
            width: BiblePointWidth.half,
          ),
          _f(
            night,
            'De noche',
            hint: 'Qué fuentes mandan, qué se apaga, qué se añade…',
            width: BiblePointWidth.half,
          ),
          _palette('Paleta de esta luz'),
          _f(
            sources,
            'Fuentes y aparatos',
            type: BibleSectionFieldType.list,
            width: BiblePointWidth.half,
          ),
          _f(
            problems,
            'Problemas y soluciones',
            type: BibleSectionFieldType.cards,
            width: BiblePointWidth.half,
          ),
        ],
        NarrativeCardKind.filmRef => [
          if (!stills)
            _f(
              film,
              'La película',
              type: BibleSectionFieldType.specs,
              width: BiblePointWidth.third,
            ),
          _f(
            main,
            stills ? 'La idea que comparten' : 'Por qué esta película',
            hint: stills
                ? 'Qué tienen en común estas imágenes y qué nos dice de '
                      'nuestra luz…'
                : 'Qué hace su luz que queremos para la nuestra…',
            width: stills ? BiblePointWidth.full : BiblePointWidth.twoThirds,
          ),
          _mosaic(stills ? 'Las imágenes' : 'Stills'),
          if (!stills)
            _f(take, 'Qué nos llevamos', type: BibleSectionFieldType.cards),
          _light('Color y contraste que vemos'),
          _palette('Paleta'),
        ],
        _ => [
          _f(
            main,
            'Qué es esta luz',
            hint:
                'La idea: cómo es, qué provoca, por qué está en esta '
                'película…',
          ),
          _mosaic('Variantes'),
          _light('Luz: color y contraste'),
          _palette('Paleta de esta luz'),
          _f(how, 'Cómo se consigue', type: BibleSectionFieldType.cards),
          _f(where, 'Dónde aparece', type: BibleSectionFieldType.tags),
        ],
      };

  static List<int> _ints(Object? raw) => [
    if (raw is List)
      for (final id in raw)
        if (id is num) id.toInt(),
  ];

  static String _text(Object? v) => v?.toString().trim() ?? '';

  /// La página de una ficha: la guardada o, si no la tiene, su plantilla
  /// con lo que la ficha traía.
  factory LightingCardPage.of({
    required String kind,
    required String? body,
    required Map<String, dynamic> meta,
  }) {
    final stored = meta['page'];
    final legacyLight = meta.containsKey('light')
        ? LightingMetrics.fromJson(meta['light'])
        : LightingMetrics.fromLegacy(
            meta['metrics'] is Map
                ? Map<String, dynamic>.from(meta['metrics'] as Map)
                : const {},
          );
    // Cuerpo y métricas viven en la ficha, no en la página: los leen las
    // tarjetas y el resto de la app.
    final shared = <String, String>{
      if (_text(body).isNotEmpty) main: body!.trim(),
      if (!legacyLight.isEmpty) light: legacyLight.encode(),
    };

    if (stored is Map && stored['fields'] is List) {
      return LightingCardPage(
        fields: [
          for (final f in stored['fields'] as List)
            if (f is Map) BibleSectionField.fromJson(Map<String, dynamic>.from(f)),
        ],
        values: {
          if (stored['values'] is Map)
            for (final e in (stored['values'] as Map).entries)
              e.key.toString(): e.value.toString(),
          ...shared,
        },
      );
    }

    // Imágenes sueltas, sub-puntos y bloques de refuerzo de antes pasan a
    // ser tarjetas del mosaico.
    final cards = <BibleCard>[
      for (final id in _ints(meta['imageIds'])) BibleCard(imageIds: [id]),
      ...BibleCard.listFrom(meta['points']),
      if (meta['reinforcementBlocks'] is List)
        for (final block in meta['reinforcementBlocks'] as List)
          if (block is Map)
            BibleCard(
              body: _text(block['text']),
              imageIds: [
                if (block['imageId'] is num) (block['imageId'] as num).toInt(),
              ],
            ),
    ].where((c) => !c.isEmpty).toList();
    final colors = BiblePaletteColor.listFrom(meta['palette']);
    final filmRows = [
      ('Título', _text(meta['filmTitle'])),
      ('Año', _text(meta['filmYear'])),
      ('Dirección', _text(meta['filmDirector'])),
      ('Dirección de fotografía', _text(meta['filmDp'])),
    ];
    final stills =
        kind == NarrativeCardKind.filmRef && _text(meta['refType']) == 'stills';
    return LightingCardPage(
      fields: template(kind, stills: stills),
      values: {
        ...shared,
        if (cards.isNotEmpty) mosaic: BibleCard.encode(cards)!,
        if (colors.isNotEmpty) palette: BiblePaletteColor.encode(colors)!,
        if (kind == NarrativeCardKind.filmRef && !stills)
          film: jsonEncode([
            for (final (label, value) in filmRows)
              {'label': label, 'value': value},
          ]),
      },
    );
  }

  /// Lo que se guarda en `metaJson['page']`. Cuerpo y métricas no van
  /// aquí: se guardan en la ficha.
  Map<String, dynamic> toJson() => {
    'fields': [for (final f in fields) f.toJson()],
    'values': {
      for (final e in values.entries)
        if (e.key != main && e.key != light) e.key: e.value,
    },
  };

  LightingCardPage withFields(
    List<BibleSectionField> next, {
    Set<String> dropValues = const {},
  }) => LightingCardPage(
    fields: next,
    values: {
      for (final e in values.entries)
        if (!dropValues.contains(e.key)) e.key: e.value,
    },
  );

  LightingCardPage withValue(String key, String? value) => LightingCardPage(
    fields: fields,
    values: {
      for (final e in values.entries)
        if (e.key != key) e.key: e.value,
      if (value != null) key: value,
    },
  );

  /// Primera imagen del mosaico: sirve de portada si la ficha no tiene.
  int? get firstImageId {
    for (final card in BibleCard.listFrom(values[mosaic])) {
      if (card.imageIds.isNotEmpty) return card.imageIds.first;
    }
    return null;
  }

  LightingMetrics get metrics => LightingMetrics.fromJson(values[light]);
}
