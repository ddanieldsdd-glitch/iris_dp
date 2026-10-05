import 'dart:convert';

import 'bible_cards.dart';

/// Fases con las que nacen los actos del proyecto.
const kDefaultActPhases = ['Planteamiento', 'Nudo', 'Desenlace'];

/// Los actos del proyecto: cuántos son, cómo se llaman y en qué orden van.
/// Los comparten todas las pantallas de la biblia; cada una escribe encima
/// lo suyo (ver [BibleActsValue]).
///
/// Se guardan en `VisualBibles.actVisualNotes`.
abstract final class BibleSharedActs {
  static const _kindTurn = 'turn';

  /// Marca de «el usuario los ha quitado todos», para que no vuelvan los de
  /// partida.
  static const _kindNone = 'none';

  /// Los actos guardados, o `null` si el proyecto aún no los ha definido.
  static List<BibleCard>? decode(List<Map<String, String>> stored) {
    final acts = [
      for (final entry in stored)
        if ((entry['id'] ?? '').isNotEmpty)
          BibleCard(
            id: entry['id']!,
            kicker: entry['phase'] ?? '',
            title: entry['title'] ?? '',
            turn: entry['kind'] == _kindTurn,
          ),
    ];
    if (acts.isNotEmpty) return acts;
    return stored.any((e) => e['kind'] == _kindNone) ? const [] : null;
  }

  static List<Map<String, String>> encode(List<BibleCard> acts) => acts.isEmpty
      ? [
          {'kind': _kindNone},
        ]
      : [
          for (final act in acts)
            {
              'id': act.id,
              'phase': act.kicker,
              'title': act.title,
              if (act.turn) 'kind': _kindTurn,
            },
        ];

  /// Los actos del proyecto. Si aún no se han definido, salen de lo que
  /// hubiera escrito en Dirección y Concepto antes de compartirlos, o de
  /// tres actos de partida.
  static List<BibleCard> resolve(
    List<Map<String, String>> stored, {
    Map<String, dynamic> directionBlob = const {},
    Map<String, dynamic> conceptBlob = const {},
  }) {
    final saved = decode(stored);
    if (saved != null) return saved;
    String text(Object? v) => v?.toString().trim() ?? '';
    final conceptTitles = conceptBlob['actTitles'];
    return [
      for (var n = 1; n <= 3; n++)
        BibleCard(
          id: legacyId(n),
          kicker: text(directionBlob['act${n}Phase']).isNotEmpty
              ? text(directionBlob['act${n}Phase'])
              : kDefaultActPhases[n - 1],
          title: text(directionBlob['act${n}Title']).isNotEmpty
              ? text(directionBlob['act${n}Title'])
              : text(conceptTitles is Map ? conceptTitles['$n'] : null),
        ),
    ];
  }

  /// Identidad de los tres actos que había antes de compartirlos.
  static String legacyId(int number) => 'act$number';

  /// Da identidad a los actos nuevos de [acts].
  static List<BibleCard> withIds(List<BibleCard> acts) {
    final used = {for (final act in acts) act.id}..remove('');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    var n = 0;
    return [
      for (final act in acts)
        if (act.id.isNotEmpty)
          act
        else
          () {
            var id = 'act_${stamp}_${n++}';
            while (!used.add(id)) {
              id = 'act_${stamp}_${n++}';
            }
            return act.copyWith(id: id);
          }(),
    ];
  }
}

/// Valor de un punto «División por actos».
///
/// Con [shared], el punto usa los actos del proyecto y solo guarda lo que
/// esta pantalla dice de cada uno ([layers]: intención e imágenes por acto).
/// Sin él, lleva sus propios actos ([own]), independientes de los demás.
/// Cambiar de un modo a otro no borra lo escrito en el otro.
class BibleActsValue {
  final bool shared;
  final List<BibleCard> own;
  final Map<String, BibleCard> layers;

  const BibleActsValue({
    this.shared = false,
    this.own = const [],
    this.layers = const {},
  });

  /// [sharedByDefault] decide el modo de un punto que aún no tiene valor.
  /// Un array JSON es el formato de los puntos anteriores: actos propios.
  factory BibleActsValue.decode(String? raw, {bool sharedByDefault = false}) {
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return BibleActsValue(own: BibleCard.listFrom(decoded));
        }
        if (decoded is Map) {
          final layers = decoded['layers'];
          return BibleActsValue(
            shared: decoded['shared'] == true,
            own: BibleCard.listFrom(decoded['own']),
            layers: {
              if (layers is Map)
                for (final entry in layers.entries)
                  if (entry.value is Map)
                    entry.key.toString(): BibleCard.fromJson(
                      entry.value as Map,
                    ),
            },
          );
        }
      } catch (_) {}
    }
    return BibleActsValue(shared: sharedByDefault);
  }

  String encode() => jsonEncode({
    'shared': shared,
    if (own.isNotEmpty) 'own': [for (final act in own) act.toJson()],
    if (layers.isNotEmpty)
      'layers': {
        for (final entry in layers.entries)
          if (entry.value.body.isNotEmpty || entry.value.imageIds.isNotEmpty)
            entry.key: {
              'body': entry.value.body,
              if (entry.value.imageIds.isNotEmpty)
                'images': entry.value.imageIds,
            },
      },
  });

  BibleActsValue copyWith({
    bool? shared,
    List<BibleCard>? own,
    Map<String, BibleCard>? layers,
  }) => BibleActsValue(
    shared: shared ?? this.shared,
    own: own ?? this.own,
    layers: layers ?? this.layers,
  );

  /// Los actos tal como se ven en esta pantalla.
  List<BibleCard> resolve(List<BibleCard> sharedActs) => !shared
      ? own
      : [
          for (final act in sharedActs)
            act.copyWith(
              body: layers[act.id]?.body ?? '',
              imageIds: layers[act.id]?.imageIds ?? const [],
            ),
        ];

  /// Guarda lo que esta pantalla dice de cada acto de [acts], que ya traen
  /// identidad. Lo escrito sobre actos que no están en [acts] se conserva.
  BibleActsValue withLayersOf(List<BibleCard> acts) => copyWith(
    layers: {
      ...layers,
      for (final act in acts)
        act.id: BibleCard(body: act.body, imageIds: act.imageIds),
    },
  );

  /// Imágenes del moodboard que usa el punto, en el modo en que está.
  Iterable<int> get imageIds => shared
      ? layers.values.expand((layer) => layer.imageIds)
      : own.expand((act) => act.imageIds);
}
