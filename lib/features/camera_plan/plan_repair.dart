import '../../core/database/app_database.dart';
import 'camera_links.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'floor_plan_json.dart';
import 'floor_plan_repository.dart';
import 'floor_plan_scope.dart';
import 'light_overrides.dart';
import 'plan_trash_service.dart';

/// Muchos esquemas de una localización con un plano cada uno: se proponen
/// juntar en un solo set con varias cámaras (SG.6).
class MergeSuggestion {
  final LocationSite site;

  /// El que se queda: el que tiene más luces.
  final LightSetup target;

  /// Los que se juntan en [target] y van a la papelera.
  final List<LightSetup> sources;

  /// Planos que pasan a [target].
  final int shots;

  const MergeSuggestion({
    required this.site,
    required this.target,
    required this.sources,
    required this.shots,
  });
}

/// Un esquema con luz que no usa ningún plano, en una localización con
/// planos sin luz (SG.6).
class AssignSuggestion {
  final LocationSite site;
  final LightSetup setup;
  final List<Shot> shots;

  const AssignSuggestion({
    required this.site,
    required this.setup,
    required this.shots,
  });
}

/// Lo dibujado en una zona (que ya no se enseña): se propone pasarlo al
/// entorno de la localización, que ven todos sus sets (SG.6).
class ZoneSuggestion {
  final LocationSite site;
  final LocationBasePlan zone;
  final int elements;

  /// ¿Es la única zona dibujada de la localización? Entonces se marca.
  final bool alone;

  const ZoneSuggestion({
    required this.site,
    required this.zone,
    required this.elements,
    required this.alone,
  });
}

class PlanRepairReport {
  final List<MergeSuggestion> merges;
  final List<AssignSuggestion> assigns;
  final List<ZoneSuggestion> zones;

  const PlanRepairReport({
    this.merges = const [],
    this.assigns = const [],
    this.zones = const [],
  });

  bool get isEmpty => merges.isEmpty && assigns.isEmpty && zones.isEmpty;
}

/// «Ordenar la planta» (SG.6): encuentra el lío de esquemas (uno por plano,
/// casi vacíos; o uno dibujado que no usa nadie) y lo arregla. Lo que se
/// quita va a la papelera de plantas.
class PlanRepair {
  final AppDatabase db;
  PlanRepair(this.db);

  /// Una localización con al menos tantos esquemas de un solo plano se
  /// propone juntar.
  static const minOnePerShot = 3;

  Future<PlanRepairReport> analyze(int projectId) async {
    final sites = await (db.select(
      db.locationSites,
    )..where((s) => s.projectId.equals(projectId))).get();
    final sets = await (db.select(
      db.locationBasePlans,
    )..where((s) => s.projectId.equals(projectId))).get();
    final setups = [
      for (final s in await db.getLightSetupsForProject(projectId))
        if (s.kind == LightSetupKind.plan) s,
    ];
    final scenes = await (db.select(
      db.scenes,
    )..where((s) => s.projectId.equals(projectId))).get();
    final shots = await db.getShotsForProject(projectId);
    final repo = FloorPlanRepository(db);

    int? siteOfSetup(LightSetup s) {
      if (s.locationSiteId != null) return s.locationSiteId;
      for (final set in sets) {
        if (set.id == s.locationBasePlanId) return set.siteId;
      }
      return null;
    }

    final sceneSite = {for (final s in scenes) s.id: s.locationSiteId};
    final merges = <MergeSuggestion>[];
    final assigns = <AssignSuggestion>[];
    final zones = <ZoneSuggestion>[];
    for (final site in sites) {
      final drawn = [
        for (final zone in sets)
          if (zone.siteId == site.id)
            (
              zone: zone,
              count: FloorPlanJson.decode(zone.floorPlanJson).length,
            ),
      ].where((z) => z.count > 0).toList();
      for (final z in drawn) {
        zones.add(
          ZoneSuggestion(
            site: site,
            zone: z.zone,
            elements: z.count,
            alone: drawn.length == 1,
          ),
        );
      }

      final own = [
        for (final s in setups)
          if (siteOfSetup(s) == site.id) s,
      ];
      if (own.isEmpty) continue;
      final users = {
        for (final s in own)
          s.id: shots.where((sh) => sh.lightSetupId == s.id).length,
      };
      final lights = <int, int>{};
      for (final s in own) {
        final els = await repo.loadElements(
          scope: FloorPlanScope.lightSetup,
          lightSetupId: s.id,
        );
        lights[s.id] = els.where((e) => e.type == ElementType.light).length;
      }

      // Uno por plano: esquemas con un plano (o ninguno) y casi nada.
      final onePerShot = [
        for (final s in own)
          // Los de un plano, y los vacíos que no usa nadie. Uno dibujado
          // que no usa nadie no se toca: se propone asignarlo.
          if (users[s.id] == 1 || (users[s.id] == 0 && lights[s.id] == 0)) s,
      ];
      final single = onePerShot.where((s) => users[s.id] == 1).length;
      if (single >= minOnePerShot) {
        final target = onePerShot.reduce(
          (a, b) => lights[b.id]! > lights[a.id]! ? b : a,
        );
        final sources = [
          for (final s in onePerShot)
            if (s.id != target.id) s,
        ];
        merges.add(
          MergeSuggestion(
            site: site,
            target: target,
            sources: sources,
            shots: [
              for (final s in onePerShot) users[s.id]!,
            ].fold(0, (a, b) => a + b),
          ),
        );
      }

      // Un esquema con luz que nadie usa, y planos de la localización sin luz.
      final orphans = [
        for (final sh in shots)
          if (sh.lightSetupId == null && sceneSite[sh.sceneId] == site.id) sh,
      ];
      if (orphans.isEmpty) continue;
      final lit = [
        for (final s in own)
          if (users[s.id] == 0 && lights[s.id]! > 0) s,
      ]..sort((a, b) => lights[b.id]!.compareTo(lights[a.id]!));
      if (lit.isNotEmpty) {
        assigns.add(
          AssignSuggestion(site: site, setup: lit.first, shots: orphans),
        );
      }
    }
    return PlanRepairReport(merges: merges, assigns: assigns, zones: zones);
  }

  /// Junta [sources] en [targetId]: sus luces, cámaras y actores pasan a la
  /// planta del que se queda (los repetidos en el mismo sitio, una vez), sus
  /// planos pasan a usarlo y ellos van a la papelera. Las cámaras conservan
  /// su identidad, así que sus planos siguen vinculados.
  Future<void> merge(int targetId, Iterable<int> sources) async {
    final repo = FloorPlanRepository(db);
    final trash = PlanTrashService(db);
    final target = await repo.loadElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: targetId,
    );
    LightOverrides.ensureUids(target);
    final uids = {for (final e in target) LightOverrides.uidOf(e)};
    var letters = target.where((e) => e.type == ElementType.camera).length;
    final relettered = <String, String>{};

    bool repeated(PlanElement e) => target.any(
      (t) =>
          t.type == e.type &&
          t.type != ElementType.camera &&
          t.lightType == e.lightType &&
          t.propType == e.propType &&
          (t.position - e.position).distance < 1,
    );

    final ids = sources.where((id) => id != targetId).toList();
    for (final id in ids) {
      final els = await repo.loadElements(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: id,
      );
      LightOverrides.ensureUids(els);
      for (final e in els) {
        if (repeated(e)) continue;
        if (uids.contains(LightOverrides.uidOf(e))) {
          LightOverrides.renewUids([e]);
        }
        if (e.type == ElementType.camera) {
          final letter = String.fromCharCode(65 + letters % 26);
          letters++;
          relettered[LightOverrides.uidOf(e)!] = letter;
          e
            ..cameraLetter = letter
            ..cameraNumber = letters;
        }
        e.layer = PlanLayer.light;
        uids.add(LightOverrides.uidOf(e));
        target.add(e);
      }
    }
    await repo.saveElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: targetId,
      elements: target,
    );
    for (final id in ids) {
      final shots = await (db.select(
        db.shots,
      )..where((s) => s.lightSetupId.equals(id))).get();
      for (final shot in shots) {
        await db.assignLightSetupToShot(shot.id, targetId);
        if (relettered.isEmpty) continue;
        // Sus copias de cámara llevan la letra nueva.
        final own = await repo.loadElements(
          scope: FloorPlanScope.shot,
          shotId: shot.id,
        );
        var touched = false;
        for (final e in own) {
          final letter = relettered[CameraLinks.setupCameraOf(e)];
          if (letter != null && e.cameraLetter != letter) {
            e.cameraLetter = letter;
            touched = true;
          }
        }
        if (touched) {
          await repo.saveElements(
            scope: FloorPlanScope.shot,
            shotId: shot.id,
            elements: own,
          );
        }
      }
      await trash.deleteLightSetup(id);
    }
  }

  /// Lo dibujado en la zona pasa al entorno de su localización: lo ven
  /// todos sus sets y se edita desde cualquiera. La zona se queda vacía.
  Future<void> foldZone(int zoneId) async {
    final zone = await db.getLocationById(zoneId);
    final siteId = zone?.siteId;
    if (zone == null || siteId == null) return;
    final repo = FloorPlanRepository(db);
    final moving = FloorPlanJson.decode(zone.floorPlanJson);
    if (moving.isEmpty) return;
    final env = [
      ...await repo.loadElements(scope: FloorPlanScope.site, siteId: siteId),
    ];
    LightOverrides.ensureUids([...env, ...moving]);
    final uids = {for (final e in env) LightOverrides.uidOf(e)};
    for (final e in moving) {
      if (uids.contains(LightOverrides.uidOf(e))) LightOverrides.renewUids([e]);
      e.layer = PlanLayer.environment;
      env.add(e);
    }
    await repo.saveElements(
      scope: FloorPlanScope.site,
      siteId: siteId,
      elements: env,
    );
    await repo.saveElements(
      scope: FloorPlanScope.set,
      setId: zoneId,
      elements: const [],
    );
  }

  /// Los [shots] pasan a usar el esquema [setupId].
  Future<void> assign(int setupId, Iterable<int> shots) async {
    for (final id in shots) {
      await db.assignLightSetupToShot(id, setupId);
    }
  }
}
