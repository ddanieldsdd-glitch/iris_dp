import 'dart:convert';

import '../../core/database/app_database.dart';
import '../../core/database/shoot_block_overrides.dart';
import 'shoot_day_timeline.dart';

/// Dónde se rueda una escena: su localización y el set (esquema de luz)
/// de sus planos.
typedef ShootPlace = ({int? siteId, int? setId});

/// Una parada de la jornada: un sitio donde se rueda una tanda de escenas
/// seguidas, con cuánto se tarda allí y el traslado para llegar.
///
/// Sale sola del orden de rodaje. Se ajusta con una franja «Cambio de
/// localización» con su sitio (parada a mano, que manda hasta la escena
/// siguiente que esté en otro sitio) y con un tiempo fijado
/// ([ShootStopMinutes]) en el primer bloque de la parada.
class ShootDayStop {
  final int? siteId;
  final int? setId;

  /// La escenas que se ruedan aquí, en orden.
  final List<int> sceneIds;

  /// El bloque que manda en la parada: la franja de la parada a mano o el
  /// primero de su primera escena. Ahí se guarda el tiempo fijado.
  final ShootDocumentBlock firstBlock;

  /// La abre una franja de cambio de localización con su sitio.
  final bool manual;

  /// Cuándo empieza y acaba lo que se rueda aquí (sin el traslado).
  final int? start;
  final int? end;

  /// Lo que suman sus escenas.
  final int computedMinutes;

  /// Lo fijado a mano; manda sobre lo calculado.
  final int? fixedMinutes;

  /// El traslado hasta aquí (franjas de cambio de localización).
  final int travelMinutes;

  const ShootDayStop({
    required this.siteId,
    required this.setId,
    required this.sceneIds,
    required this.firstBlock,
    this.manual = false,
    this.start,
    this.end,
    this.computedMinutes = 0,
    this.fixedMinutes,
    this.travelMinutes = 0,
  });

  /// El tiempo estimado de la parada.
  int get minutes => fixedMinutes ?? computedMinutes;

  ShootDayStop _with({
    int? setId,
    List<int>? sceneIds,
    int? start,
    int? end,
    int? computedMinutes,
  }) => ShootDayStop(
    siteId: siteId,
    setId: setId ?? this.setId,
    sceneIds: sceneIds ?? this.sceneIds,
    firstBlock: firstBlock,
    manual: manual,
    start: start ?? this.start,
    end: end ?? this.end,
    computedMinutes: computedMinutes ?? this.computedMinutes,
    fixedMinutes: fixedMinutes,
    travelMinutes: travelMinutes,
  );
}

/// El tiempo de una parada fijado a mano. Va en `contentOverridesJson` del
/// primer bloque de la parada, como las horas: viaja sin tocar el esquema.
abstract final class ShootStopMinutes {
  static const _key = 'stopMinutes';

  static int? of(ShootDocumentBlock block) =>
      (decodeBlockOverrides(block.contentOverridesJson)[_key] as num?)?.toInt();

  static String writeInto(String? json, int? minutes) {
    final all = decodeBlockOverrides(json);
    if (minutes == null) {
      all.remove(_key);
    } else {
      all[_key] = minutes;
    }
    return jsonEncode(all);
  }
}

int? _spanMinutes(ShootSpan? span) =>
    span == null ? null : span.end - span.start;

/// Las paradas de la jornada, en el orden de rodaje.
///
/// [placeOf] dice dónde se rueda cada escena; [siteOfUid] traduce el sitio
/// de una franja (guardado por uid). Las escenas seguidas en el mismo sitio
/// y set van en la misma parada; una franja de comida o de nota no corta.
List<ShootDayStop> deriveShootDayStops(
  List<ShootDayEntry> entries,
  ShootDaySchedule schedule, {
  required ShootPlace Function(ShootSceneEntry entry) placeOf,
  required int? Function(String uid) siteOfUid,
}) {
  final stops = <ShootDayStop>[];
  var travel = 0;

  void extend(ShootSceneEntry entry, ShootPlace place) {
    final head = entry.blocks.first.id;
    final span = schedule.sceneSpans[head];
    final minutes = _spanMinutes(span) ?? schedule.sceneMinutes[head] ?? 0;
    final last = stops.last;
    stops[stops.length - 1] = last._with(
      setId: last.setId ?? place.setId,
      sceneIds: [...last.sceneIds, entry.sceneId],
      start: last.start ?? span?.start,
      end: span?.end ?? last.end,
      computedMinutes: last.computedMinutes + minutes,
    );
  }

  for (final entry in entries) {
    switch (entry) {
      case ShootStripEntry(:final block, :final strip):
        if (strip.kind != ShootStripKind.move) continue;
        final minutes =
            _spanMinutes(schedule.spans[block.id]) ??
            strip.minutes ??
            clockSpan(strip.from, strip.to) ??
            0;
        final siteId = strip.siteUid == null ? null : siteOfUid(strip.siteUid!);
        if (siteId == null) {
          travel += minutes;
          continue;
        }
        stops.add(
          ShootDayStop(
            siteId: siteId,
            setId: null,
            sceneIds: const [],
            firstBlock: block,
            manual: true,
            fixedMinutes: ShootStopMinutes.of(block),
            travelMinutes: travel + minutes,
          ),
        );
        travel = 0;
      case ShootSceneEntry():
        final place = placeOf(entry);
        final last = stops.lastOrNull;
        final same =
            last != null &&
            last.siteId == place.siteId &&
            (last.setId == place.setId ||
                place.setId == null ||
                (last.manual && last.sceneIds.isEmpty));
        // Una parada a mano acoge lo que se rueda en su sitio, aunque las
        // escenas no lo digan.
        final adopt =
            last != null &&
            last.manual &&
            last.sceneIds.isEmpty &&
            place.siteId == null;
        if (!same && !adopt) {
          stops.add(
            ShootDayStop(
              siteId: place.siteId,
              setId: place.setId,
              sceneIds: const [],
              firstBlock: entry.blocks.first,
              fixedMinutes: ShootStopMinutes.of(entry.blocks.first),
              travelMinutes: travel,
            ),
          );
          travel = 0;
        }
        extend(entry, place);
    }
  }
  return stops;
}
