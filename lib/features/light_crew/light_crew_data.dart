import '../../core/database/app_database.dart';
import '../../shared/pdf_export/shoot_day_material.dart';
import '../camera_plan/camera_plan_element_model.dart';
import '../camera_plan/light_sheet_jobs.dart';
import '../camera_plan/plan_data.dart';
import '../camera_plan/plan_gear_list.dart';
import '../camera_plan/plan_power.dart';
import '../shoot_documents/shoot_plan.dart';

/// Un esquema de luz tal como lo ve el eléctrico: su planta, sus focos y lo
/// que consume.
class LightCrewScheme {
  final LightSchemeUse use;
  final List<PlanElement> elements;
  final double metersPerUnit;
  final List<PowerLoad> loads;

  const LightCrewScheme({
    required this.use,
    required this.elements,
    required this.metersPerUnit,
    required this.loads,
  });

  String get name => use.setup.name;
  int get lightCount => lightUnitNumbers(elements).length;
  double get watts => loads.fold(0, (s, l) => s + l.watts);
  double get amps => watts / GearList.mainsVolts;
}

/// Una jornada para el eléctrico: los esquemas que se montan y el material.
class LightCrewDay {
  /// Nula: el proyecto aún no tiene jornadas y se enseña todo el guion.
  final ShootDocument? day;
  final List<LightCrewScheme> schemes;
  final ShootDayMaterial material;

  const LightCrewDay(this.day, this.schemes, this.material);

  String get title => day?.name ?? 'Todo el guion';

  /// El esquema que más consume: lo que hay que poder alimentar a la vez.
  LightCrewScheme? get heaviest => schemes.isEmpty
      ? null
      : schemes.reduce((a, b) => b.watts > a.watts ? b : a);
}

/// La vista de consulta de los eléctricos (LZ.3): por jornada, las plantas y
/// hojas de luz de cada esquema, sus vatios y el material de luz del día.
class LightCrewData {
  final Project project;
  final PlanProjectData plan;
  final List<LightCrewDay> days;

  const LightCrewData(this.project, this.plan, this.days);

  static Future<LightCrewData?> load(AppDatabase db, int projectId) async {
    final project = await db.getProject(projectId);
    if (project == null) return null;
    final data = await PlanProjectData.load(db, projectId);
    final shots = await db.getShotsForProject(projectId);
    final shotById = {for (final s in shots) s.id: s};
    final scenes = await db.watchScenesForProject(projectId).first;
    final plan = ShootPlan.from(
      documents: await db.getShootDocumentsForProject(projectId),
      blocks: await db.getShootDayBlocks(projectId),
      scenes: scenes,
      shots: shots,
    );

    Future<LightCrewDay> dayOf(ShootDocument? day, List<Shot> dayShots) async {
      final uses = [
        for (final shot in dayShots)
          (
            shot: shot,
            scene: data.scene(shot.sceneId)?.label ?? '',
            day: day?.name,
          ),
      ];
      final schemes = [
        for (final use in lightSchemesOf(data, uses))
          () {
            final sheet = data.lightSheetOf(use.setup);
            return LightCrewScheme(
              use: use,
              elements: sheet.elements,
              metersPerUnit: sheet.metersPerUnit,
              loads: PowerPlan.loadsOf(sheet.elements),
            );
          }(),
      ];
      final material = await ShootDayMaterial.load(
        db,
        data,
        projectId,
        dayShots,
        date: day?.shootDate,
      );
      return LightCrewDay(day, schemes, material);
    }

    final days = <LightCrewDay>[];
    for (final day in plan.days) {
      final dayShots = <Shot>[];
      for (final block in plan.blocksByDay[day.id] ?? const []) {
        final shot = shotById[block.shotId];
        if (shot != null && !dayShots.contains(shot)) dayShots.add(shot);
      }
      days.add(await dayOf(day, dayShots));
    }
    if (days.isEmpty) days.add(await dayOf(null, shots));
    return LightCrewData(project, data, days);
  }
}
