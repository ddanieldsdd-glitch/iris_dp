import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'floor_plan_json.dart';
import 'floor_plan_repository.dart';
import 'floor_plan_scope.dart';

/// Orden de trabajo de la planta: primero la localización, luego sus sets y
/// por último los planos de cada set.
enum PlanGuideStep { location, sets, shots }

/// Lo que le falta a un plano para tener planta.
enum PlanEntryNeed {
  /// La escena no tiene localización.
  site,

  /// La localización existe pero su plano maestro está vacío.
  sitePlan,

  /// La localización no tiene sets.
  sets,

  /// El plano no está en ningún set.
  shotSet,

  /// Todo listo: se abre la planta del plano.
  none,
}

/// Dónde está un plano en el orden localización › set › plano.
class PlanEntryState {
  final Shot shot;
  final Scene? scene;
  final LocationSite? site;
  final List<LocationBasePlan> sets;

  /// El set donde se rueda: el suyo o el de su escena.
  final LocationBasePlan? set;
  final bool sitePlanEmpty;

  const PlanEntryState({
    required this.shot,
    required this.scene,
    required this.site,
    required this.sets,
    required this.set,
    required this.sitePlanEmpty,
  });

  PlanEntryNeed get need {
    if (site == null) return PlanEntryNeed.site;
    if (sitePlanEmpty) return PlanEntryNeed.sitePlan;
    if (sets.isEmpty) return PlanEntryNeed.sets;
    if (set == null) return PlanEntryNeed.shotSet;
    return PlanEntryNeed.none;
  }

  /// Paso de la guía por el que se empieza.
  PlanGuideStep get startStep => switch (need) {
    PlanEntryNeed.site || PlanEntryNeed.sitePlan => PlanGuideStep.location,
    PlanEntryNeed.sets => PlanGuideStep.sets,
    PlanEntryNeed.shotSet || PlanEntryNeed.none => PlanGuideStep.shots,
  };

  /// Texto corto para la celda del guion técnico, o nulo si no falta nada.
  String? get missingLabel => switch (need) {
    PlanEntryNeed.site || PlanEntryNeed.sitePlan => 'Falta localización',
    PlanEntryNeed.sets => 'Falta set',
    PlanEntryNeed.shotSet => 'Sin set',
    PlanEntryNeed.none => null,
  };

  static Future<PlanEntryState> resolve(AppDatabase db, Shot shot) async {
    final scene = await (db.select(
      db.scenes,
    )..where((s) => s.id.equals(shot.sceneId))).getSingleOrNull();
    final siteId = scene?.locationSiteId;
    final site = siteId == null ? null : await db.getSiteById(siteId);
    final sets = site == null
        ? const <LocationBasePlan>[]
        : await db.watchSetsForSite(site.id).first;
    final setId = shot.locationBasePlanId ?? scene?.locationId;
    final set = setId == null ? null : await db.getLocationById(setId);
    return PlanEntryState(
      shot: shot,
      scene: scene,
      site: site,
      sets: sets,
      set: set,
      sitePlanEmpty: FloorPlanJson.decode(site?.floorPlanJson).isEmpty,
    );
  }
}

/// La guía con la que se abre el plano maestro cuando a un plano le falta
/// la localización o el set.
class PlanGuide {
  final int sceneId;

  /// El plano desde el que se llegó: al terminar se abre su planta.
  final int? shotId;
  final String? shotLabel;
  final PlanGuideStep startStep;

  const PlanGuide({
    required this.sceneId,
    this.shotId,
    this.shotLabel,
    this.startStep = PlanGuideStep.location,
  });
}

/// Pregunta a qué localización va la escena (una de las que hay o una
/// nueva) y la enlaza. Devuelve la localización, o nula si se cancela.
Future<LocationSite?> pickSiteForScene(
  BuildContext context,
  AppDatabase db,
  Scene scene,
) async {
  final sites = await (db.select(
    db.locationSites,
  )..where((s) => s.projectId.equals(scene.projectId))).get();
  if (!context.mounted) return null;
  final suggested = scene.locationPureName.trim().isEmpty
      ? 'Localización'
      : scene.locationPureName.trim();
  final controller = TextEditingController(text: suggested);
  final palette = context.palette;
  final picked = await showDialog<Object>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(
        '¿Dónde se rueda la escena ${scene.number}?',
        style: AppTypography.titleMedium(palette),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Primero la localización: su plano maestro lleva el entorno. '
              'Después se marcan los sets y se reparten los planos.',
              style: AppTypography.bodyMedium(
                palette,
              ).copyWith(color: palette.textSecondary),
            ),
            if (sites.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final site in sites)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_city_outlined),
                  title: Text(site.name),
                  onTap: () => Navigator.pop(ctx, site),
                ),
              const Divider(),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Localización nueva',
                hintText: 'Casa, bosque, hospital…',
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Crear localización'),
        ),
      ],
    ),
  );
  LocationSite? site;
  if (picked is LocationSite) {
    site = picked;
  } else if (picked is String && picked.trim().isNotEmpty) {
    site = await db.ensureSite(
      projectId: scene.projectId,
      siteName: picked.trim(),
    );
  }
  if (site == null) return null;
  await (db.update(db.scenes)..where((s) => s.id.equals(scene.id))).write(
    ScenesCompanion(locationSiteId: Value(site.id)),
  );
  await db.touchProjectContent(scene.projectId);
  return site;
}

/// Lleva los planos al set; los que aún no tienen cámara reciben una, en
/// la zona del set. Si la escena no tenía set, toma este.
Future<void> associateShotsToSet(
  AppDatabase db,
  LocationBasePlan set,
  Iterable<Shot> shots,
) async {
  final repo = FloorPlanRepository(db);
  final setups = (await db.getLightSetupsForProject(
    set.projectId,
  )).where((s) => s.locationBasePlanId == set.id).map((s) => s.id).toSet();
  final zone = SetZone.decode(set.sitePlacementJson);
  var placed = 0;
  for (final shot in shots) {
    final scene = await (db.select(
      db.scenes,
    )..where((s) => s.id.equals(shot.sceneId))).getSingleOrNull();
    if (scene != null && scene.locationId == null) {
      await (db.update(db.scenes)..where((s) => s.id.equals(scene.id))).write(
        ScenesCompanion(locationId: Value(set.id)),
      );
    }
    final viaScene = scene?.locationId == null || scene?.locationId == set.id;
    await db.moveShot(
      shot.id,
      // Si su escena ya va a este set, el plano lo hereda.
      setId: viaScene ? null : set.id,
      // Conserva su esquema solo si es de este set.
      lightSetupId: setups.contains(shot.lightSetupId)
          ? shot.lightSetupId
          : null,
    );
    final elements = await repo.loadElements(
      scope: FloorPlanScope.shot,
      shotId: shot.id,
    );
    if (elements.any((e) => e.type == ElementType.camera)) continue;
    await repo.saveElements(
      scope: FloorPlanScope.shot,
      shotId: shot.id,
      elements: [
        ...elements,
        PlanElement(
          id: 0,
          type: ElementType.camera,
          position: _cameraSpot(zone, placed++),
          stabilization: shot.movement ?? 'STEADY',
          lens: shot.lens ?? '50mm',
        ),
      ],
    );
  }
}

/// Sitio para la cámara nueva: repartidas dentro de la zona del set.
Offset _cameraSpot(Rect? zone, int index) {
  final area = zone ?? const Rect.fromLTWH(100, 100, 400, 300);
  final step = (index % 4) + 1;
  final row = index ~/ 4;
  return Offset(
    area.left + area.width * step / 5,
    area.top + area.height * (0.35 + 0.3 * (row % 2)),
  );
}

/// Lista con casillas de los planos de [scenes] para llevarlos a [set].
/// Los que ya están en el set salen marcados. Devuelve si se asoció algo.
Future<bool> showAssociateShotsDialog(
  BuildContext context,
  AppDatabase db, {
  required LocationBasePlan set,
  required List<Scene> scenes,
}) async {
  final sceneIds = {for (final s in scenes) s.id};
  final shots = [
    for (final shot in await db.getShotsForProject(set.projectId))
      if (sceneIds.contains(shot.sceneId)) shot,
  ]..sort((a, b) => a.number.compareTo(b.number));
  final sets = {
    for (final s in await (db.select(
      db.locationBasePlans,
    )..where((s) => s.projectId.equals(set.projectId))).get())
      s.id: s,
  };
  if (!context.mounted) return false;
  final sceneById = {for (final s in scenes) s.id: s};
  int? setOf(Shot shot) =>
      shot.locationBasePlanId ?? sceneById[shot.sceneId]?.locationId;
  final picked = {
    for (final shot in shots)
      if (setOf(shot) == set.id) shot.id,
  };
  final already = {...picked};
  final palette = context.palette;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final adding = picked.difference(already).length;
        return AlertDialog(
          backgroundColor: palette.surfaceElevated,
          title: Text(
            'Asociar planos a «${set.locationName}»',
            style: AppTypography.titleMedium(palette),
          ),
          content: SizedBox(
            width: 420,
            child: shots.isEmpty
                ? Text(
                    'Estas escenas aún no tienen planos. Créalos en el guion '
                    'técnico.',
                    style: AppTypography.bodyMedium(palette),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final scene in scenes)
                        if (shots.any((s) => s.sceneId == scene.id)) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 2),
                            child: Text(
                              'Escena ${scene.number} · '
                              '${scene.locationCanonical}',
                              style: AppTypography.caption(
                                palette,
                              ).copyWith(color: palette.textSecondary),
                            ),
                          ),
                          for (final shot in shots)
                            if (shot.sceneId == scene.id)
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: picked.contains(shot.id),
                                // Lo que ya está en el set no se quita
                                // aquí: se quita desde el plano.
                                onChanged: already.contains(shot.id)
                                    ? null
                                    : (v) => setState(() {
                                        if (v == true) {
                                          picked.add(shot.id);
                                        } else {
                                          picked.remove(shot.id);
                                        }
                                      }),
                                title: Text(
                                  [
                                    'Plano ${shot.number}',
                                    ?shot.framing,
                                    ?shot.lens,
                                  ].join(' · '),
                                ),
                                subtitle: _shotNote(
                                  palette,
                                  already.contains(shot.id),
                                  sets[setOf(shot)],
                                ),
                              ),
                        ],
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: adding == 0 ? null : () => Navigator.pop(ctx, true),
              child: Text(
                adding == 0
                    ? 'Asociar'
                    : 'Asociar $adding plano${adding == 1 ? '' : 's'}',
              ),
            ),
          ],
        );
      },
    ),
  );
  if (ok != true) return false;
  await associateShotsToSet(db, set, [
    for (final shot in shots)
      if (picked.contains(shot.id) && !already.contains(shot.id)) shot,
  ]);
  return true;
}

Widget? _shotNote(AppPalette palette, bool here, LocationBasePlan? current) {
  if (here) {
    return Text(
      'Ya está en este set',
      style: AppTypography.caption(
        palette,
      ).copyWith(color: palette.textTertiary),
    );
  }
  if (current == null) return null;
  return Text(
    'Ahora en «${current.locationName}»: se movería',
    style: AppTypography.caption(
      palette,
    ).copyWith(color: palette.warning),
  );
}

/// Barra de la guía, arriba del lienzo: los tres pasos y lo que toca hacer.
class PlanGuideBar extends StatelessWidget {
  final PlanGuideStep step;
  final String siteName;
  final List<LocationBasePlan> sets;

  /// Sets con zona marcada en el plano maestro.
  final Set<int> zonedSetIds;

  /// Sets con algún plano de la escena.
  final Set<int> setsWithShots;
  final String? shotLabel;

  /// El plano de partida ya tiene set: se puede abrir su planta.
  final bool shotReady;
  final ValueChanged<PlanGuideStep> onStep;
  final VoidCallback onNewSet;
  final ValueChanged<LocationBasePlan> onMarkZone;
  final ValueChanged<LocationBasePlan> onAssociate;
  final VoidCallback onFinish;
  final VoidCallback onClose;

  const PlanGuideBar({
    super.key,
    required this.step,
    required this.siteName,
    required this.sets,
    required this.zonedSetIds,
    required this.setsWithShots,
    required this.shotLabel,
    required this.shotReady,
    required this.onStep,
    required this.onNewSet,
    required this.onMarkZone,
    required this.onAssociate,
    required this.onFinish,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget chip(PlanGuideStep s, String text) {
      final current = s == step;
      final done = s.index < step.index;
      return InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onStep(s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: current ? palette.accent.withValues(alpha: 0.15) : null,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: current ? palette.accent : palette.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (done) ...[
                Icon(Icons.check, size: 14, color: palette.success),
                const SizedBox(width: 4),
              ],
              Text(
                '${s.index + 1} · $text',
                style: AppTypography.caption(palette).copyWith(
                  color: current ? palette.accent : palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget arrow() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(Icons.chevron_right, size: 16, color: palette.textTertiary),
    );

    final (String hint, Widget next) = switch (step) {
      PlanGuideStep.location => (
        'Dibuja el entorno de «$siteName»: paredes, puertas, ventanas, '
            'calles, árboles y relieve. Las luces y cámaras van después.',
        FilledButton.tonal(
          onPressed: () => onStep(PlanGuideStep.sets),
          child: const Text('Siguiente: sets'),
        ),
      ),
      PlanGuideStep.sets => (
        sets.isEmpty
            ? 'Crea los sets de «$siteName» y marca en el plano la zona '
                  'de cada uno.'
            : 'Marca la zona de cada set arrastrando sobre el plano.',
        FilledButton.tonal(
          onPressed: sets.isEmpty ? null : () => onStep(PlanGuideStep.shots),
          child: const Text('Siguiente: planos'),
        ),
      ),
      PlanGuideStep.shots => (
        'Asocia a cada set los planos que se ruedan en él. Cada plano '
            'entra con su cámara.',
        FilledButton.tonal(
          onPressed: shotReady ? onFinish : null,
          child: Text(
            shotLabel == null ? 'Terminar' : 'Abrir planta de $shotLabel',
          ),
        ),
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 4,
                  children: [
                    chip(PlanGuideStep.location, 'Localización'),
                    arrow(),
                    chip(PlanGuideStep.sets, 'Sets'),
                    arrow(),
                    chip(PlanGuideStep.shots, 'Planos'),
                  ],
                ),
              ),
              next,
              IconButton(
                tooltip: 'Cerrar la guía',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, size: 18, color: palette.textTertiary),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hint,
            style: AppTypography.caption(
              palette,
            ).copyWith(color: palette.textSecondary),
          ),
          if (step != PlanGuideStep.location) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final set in sets)
                  step == PlanGuideStep.sets
                      ? ActionChip(
                          avatar: Icon(
                            zonedSetIds.contains(set.id)
                                ? Icons.check_box_outlined
                                : Icons.crop_free,
                            size: 16,
                          ),
                          label: Text(
                            zonedSetIds.contains(set.id)
                                ? set.locationName
                                : '${set.locationName} · marcar zona',
                          ),
                          onPressed: () => onMarkZone(set),
                        )
                      : ActionChip(
                          avatar: Icon(
                            setsWithShots.contains(set.id)
                                ? Icons.videocam_outlined
                                : Icons.add,
                            size: 16,
                          ),
                          label: Text('${set.locationName} · asociar planos'),
                          onPressed: () => onAssociate(set),
                        ),
                if (step == PlanGuideStep.sets)
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Nuevo set'),
                    onPressed: onNewSet,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
