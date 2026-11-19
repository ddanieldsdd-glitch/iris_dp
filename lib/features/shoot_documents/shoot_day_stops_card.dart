import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/places/static_map.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../camera_plan/plan_data.dart';
import '../locations/site_place.dart';
import 'shoot_day_stops.dart';
import 'shoot_day_timeline.dart';

/// Dónde se rueda cada escena para las paradas: su localización y el set
/// de luz de su primer plano que lo tenga (o el de la escena).
ShootPlace shootPlaceOf(
  PlanProjectData data,
  Map<int, Shot> shots,
  ShootSceneEntry entry,
) {
  final scene = data.scene(entry.sceneId);
  final siteId = scene == null ? null : data.siteIdOfScene(scene);
  int? setId;
  for (final block in entry.blocks) {
    final shot = shots[block.shotId];
    if (shot?.lightSetupId case final id?) {
      setId = id;
      break;
    }
  }
  return (siteId: siteId, setId: setId);
}

/// Las paradas de una jornada a partir de sus bloques.
List<ShootDayStop> shootDayStopsOf(
  PlanProjectData data,
  List<ShootDocumentBlock> blocks, {
  String? dayStart,
  String? dayEnd,
}) {
  final shots = {for (final s in data.shots) s.id: s};
  final entries = buildShootDayEntries(blocks, shots);
  final siteByUid = {
    for (final s in data.sites)
      if (s.uid != null) s.uid!: s.id,
  };
  return deriveShootDayStops(
    entries,
    scheduleShootDay(entries, shots, dayStart: dayStart, dayEnd: dayEnd),
    placeOf: (e) => shootPlaceOf(data, shots, e),
    siteOfUid: (uid) => siteByUid[uid],
  );
}

/// Los puntos del mapa del día: uno por sitio ubicado, con los números de
/// sus paradas («1·3» si se vuelve), en el orden en que se llega.
List<({double latitude, double longitude, String label})> stopsMapPoints(
  PlanProjectData data,
  List<ShootDayStop> stops,
) {
  final order = <String>[];
  final at = <String, ({double latitude, double longitude})>{};
  final numbers = <String, List<int>>{};
  for (final (i, stop) in stops.indexed) {
    final site = data.site(stop.siteId);
    final lat = site?.latitude;
    final lon = site?.longitude;
    if (lat == null || lon == null) continue;
    final key = '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
    if (!at.containsKey(key)) {
      order.add(key);
      at[key] = (latitude: lat, longitude: lon);
    }
    final list = numbers.putIfAbsent(key, () => []);
    // Dos paradas seguidas en el mismo sitio (dos sets) van como una.
    if (list.isEmpty || list.last != i) list.add(i + 1);
  }
  return [
    for (final key in order)
      (
        latitude: at[key]!.latitude,
        longitude: at[key]!.longitude,
        label: numbers[key]!.join('·'),
      ),
  ];
}

/// Las paradas de la jornada en el panel izquierdo: dónde se rueda, cuánto
/// y cómo llegar. Salen solas del orden; se añade una a mano y se fija su
/// tiempo.
class ShootDayStopsCard extends ConsumerWidget {
  final int projectId;
  final int documentId;
  final List<ShootDocumentBlock> blocks;
  final String? dayStart;
  final String? dayEnd;

  const ShootDayStopsCard({
    super.key,
    required this.projectId,
    required this.documentId,
    required this.blocks,
    this.dayStart,
    this.dayEnd,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) => PlanDataBuilder(
    projectId: projectId,
    builder: (context, data) {
      final stops = shootDayStopsOf(
        data,
        blocks,
        dayStart: dayStart,
        dayEnd: dayEnd,
      );
      final palette = context.palette;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Paradas del día',
                  style: AppTypography.label(palette),
                ),
              ),
              _AddStopButton(
                sites: data.sites,
                onPick: (site) => _addStop(ref, data, site),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (stops.isEmpty)
            Text(
              'Aparecen al añadir escenas: una por localización y set, con '
              'su tiempo.',
              style: AppTypography.caption(palette),
            )
          else ...[
            if (stopsMapPoints(data, stops) case final points
                when points.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _StopsMap(projectId: projectId, points: points),
              ),
            for (final (i, stop) in stops.indexed)
              _StopTile(
                number: i + 1,
                stop: stop,
                data: data,
                onFix: (minutes) => _fix(ref, stop, minutes),
                onPlace: data.site(stop.siteId) == null
                    ? null
                    : () =>
                          pickSitePlace(context, ref, data.site(stop.siteId)!),
              ),
          ],
        ],
      );
    },
  );

  /// Una parada a mano: un cambio de localización con su sitio al final
  /// del orden, que luego se arrastra a su sitio.
  Future<void> _addStop(
    WidgetRef ref,
    PlanProjectData data,
    LocationSite site,
  ) async {
    final db = ref.read(databaseProvider);
    final service = ShootDayScheduleService(db);
    await service.addStrip(
      documentId,
      ShootStripDraft(
        strip: ShootStrip(
          kind: ShootStripKind.move,
          siteUid: site.uid,
          minutes: 30,
        ),
        label: 'Traslado a ${site.name}',
      ),
    );
    await service.edit(
      documentId,
      await db.getBlocksForShootDocument(documentId),
      {for (final s in data.shots) s.id: s},
      dayStart: dayStart,
      dayEnd: dayEnd,
    );
  }

  Future<void> _fix(WidgetRef ref, ShootDayStop stop, int? minutes) {
    final db = ref.read(databaseProvider);
    final block = stop.firstBlock;
    return db.updateShootDocumentBlock(
      block.copyWith(
        contentOverridesJson: Value(
          ShootStopMinutes.writeInto(block.contentOverridesJson, minutes),
        ),
      ),
    );
  }
}

class _AddStopButton extends StatelessWidget {
  final List<LocationSite> sites;
  final ValueChanged<LocationSite> onPick;

  const _AddStopButton({required this.sites, required this.onPick});

  @override
  Widget build(BuildContext context) => PopupMenuButton<LocationSite>(
    enabled: sites.any((s) => s.uid != null),
    tooltip: 'Añadir una parada a mano: un traslado a otra localización',
    onSelected: onPick,
    itemBuilder: (_) => [
      for (final s in sites)
        if (s.uid != null) PopupMenuItem(value: s, child: Text(s.name)),
    ],
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_location_alt_outlined,
            size: 16,
            color: context.palette.accent,
          ),
          const SizedBox(width: 4),
          Text(
            'Parada',
            style: AppTypography.label(
              context.palette,
            ).copyWith(color: context.palette.accent),
          ),
        ],
      ),
    ),
  );
}

class _StopTile extends StatelessWidget {
  final int number;
  final ShootDayStop stop;
  final PlanProjectData data;
  final ValueChanged<int?> onFix;

  /// Fija el punto exacto de su localización en el mapa.
  final VoidCallback? onPlace;

  const _StopTile({
    required this.number,
    required this.stop,
    required this.data,
    required this.onFix,
    this.onPlace,
  });

  Future<void> _pickMinutes(BuildContext context) async {
    final controller = TextEditingController(
      text: stop.fixedMinutes == null ? '' : '${stop.fixedMinutes}',
    );
    final result = await showDialog<(bool, int?)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tiempo en esta parada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calculado del orden: ${formatDuration(stop.computedMinutes)}.',
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Minutos',
                hintText: 'p. ej. 150',
              ),
              onSubmitted: (v) => Navigator.pop(ctx, (true, int.tryParse(v))),
            ),
          ],
        ),
        actions: [
          if (stop.fixedMinutes != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, (true, null)),
              child: const Text('Volver a calcular'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, (true, int.tryParse(controller.text))),
            child: const Text('Fijar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result case (true, final minutes)) onFix(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final site = data.site(stop.siteId);
    final setup = data.setups.where((s) => s.id == stop.setId).firstOrNull;
    final scenes = [
      for (final id in stop.sceneIds)
        if (data.scene(id) case final scene?) scene.label,
    ];
    final lat = site?.latitude;
    final lon = site?.longitude;
    final when = stop.start == null
        ? null
        : shootTimeRange(
            formatClock(stop.start!),
            stop.end == null ? null : formatClock(stop.end!),
          );
    final color = site == null
        ? palette.textTertiary
        : data.colors.siteColor(site.id);

    Widget link(String text, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          text,
          style: AppTypography.caption(
            palette,
          ).copyWith(color: palette.accent, fontWeight: FontWeight.w600),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (stop.travelMinutes > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_car_outlined,
                    size: 13,
                    color: palette.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Traslado ${formatDuration(stop.travelMinutes)}',
                    style: AppTypography.caption(palette),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: color,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site?.name ?? 'Sin localización',
                      style: AppTypography.bodyLarge(
                        palette,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (setup != null)
                      Text(
                        'Set ${setup.name}',
                        style: AppTypography.caption(palette),
                      ),
                    if (scenes.isNotEmpty)
                      Text(
                        'Esc ${scenes.join(', ')}',
                        style: AppTypography.caption(palette),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (when != null)
                    Text(
                      when,
                      style: AppTypography.mono(palette).copyWith(
                        color: palette.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  Tooltip(
                    message: stop.fixedMinutes == null
                        ? 'Calculado del orden. Toca para fijarlo.'
                        : 'Fijado a mano '
                              '(del orden: ${formatDuration(stop.computedMinutes)})',
                    child: InkWell(
                      onTap: () => _pickMinutes(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (stop.fixedMinutes != null)
                              Icon(
                                Icons.push_pin,
                                size: 11,
                                color: palette.accent,
                              ),
                            Text(
                              stop.minutes == 0
                                  ? '+ tiempo'
                                  : formatDuration(stop.minutes),
                              style: AppTypography.caption(palette).copyWith(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if ((lat != null && lon != null) || onPlace != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 24),
              child: Wrap(
                spacing: 2,
                children: [
                  if (lat != null && lon != null) ...[
                    link('Maps', () => openSiteInMaps(lat, lon)),
                    link('Waze', () => openSiteInWaze(lat, lon)),
                    link('Apple', () => openSiteInAppleMaps(lat, lon)),
                  ],
                  if (onPlace != null)
                    link(
                      lat == null ? 'Ubicar en el mapa' : 'Cambiar punto',
                      onPlace!,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// El mapa del día con las paradas numeradas. Se pide una vez con red y se
/// guarda por sus puntos.
class _StopsMap extends StatefulWidget {
  final int projectId;
  final List<({double latitude, double longitude, String label})> points;

  const _StopsMap({required this.projectId, required this.points});

  @override
  State<_StopsMap> createState() => _StopsMapState();
}

class _StopsMapState extends State<_StopsMap> {
  Future<String?>? _map;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_StopsMap old) {
    super.didUpdateWidget(old);
    if (old.points.toString() != widget.points.toString()) _load();
  }

  void _load() {
    _map = ensureStopsMap(
      projectId: widget.projectId,
      stops: widget.points,
    ).catchError((Object _) => null);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _map,
    builder: (context, snap) {
      final path = snap.data;
      if (path == null) return const SizedBox.shrink();
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: AspectRatio(
          aspectRatio: StaticMap.width / StaticMap.height,
          child: Image.file(
            File(path),
            fit: BoxFit.cover,
            cacheWidth: StaticMap.width,
          ),
        ),
      );
    },
  );
}
