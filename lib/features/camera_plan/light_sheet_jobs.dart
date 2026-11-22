import '../../core/database/app_database.dart';
import '../../shared/pdf_export/rig_sheet_pdf.dart';
import 'camera_plan_constants.dart';
import 'plan_data.dart';

/// Un plano con su escena y su jornada, para saber qué esquemas de luz se
/// usan y dónde.
typedef LightShotUse = ({Shot shot, String scene, String? day});

/// Un esquema de luz usado por unos planos: en qué escenas y jornadas.
class LightSchemeUse {
  final LightSetup setup;
  final List<String> scenes;
  final List<String> days;

  const LightSchemeUse(this.setup, this.scenes, this.days);
}

/// Los esquemas de luz de [uses], en el orden en que aparecen, con sus
/// escenas y jornadas. Los que no tienen ningún foco se quedan fuera (LZ.1,
/// LZ.3).
List<LightSchemeUse> lightSchemesOf(
  PlanProjectData data,
  Iterable<LightShotUse> uses,
) {
  final scenesOf = <int, List<String>>{};
  final daysOf = <int, List<String>>{};
  for (final use in uses) {
    final id = data.setup(use.shot.lightSetupId)?.id;
    if (id == null) continue;
    final scenes = scenesOf.putIfAbsent(id, () => []);
    if (!scenes.contains(use.scene)) scenes.add(use.scene);
    final days = daysOf.putIfAbsent(id, () => []);
    if (use.day case final day? when !days.contains(day)) days.add(day);
  }
  return [
    for (final MapEntry(key: id, value: scenes) in scenesOf.entries)
      if (data.setup(id) case final setup?
          when data
              .lightSheetOf(setup)
              .elements
              .any((e) => e.type == ElementType.light))
        LightSchemeUse(setup, scenes, daysOf[id] ?? const []),
  ];
}

/// La hoja de luz de un esquema, con su cajetín.
RigSheetJob lightSheetJob(
  PlanProjectData data,
  LightSchemeUse use, {
  required String project,
}) {
  final setup = use.setup;
  final sheet = data.lightSheetOf(setup);
  return RigSheetJob(
    sheet.elements,
    sheet.metersPerUnit,
    RigSheetInfo(
      project: project,
      set: data.set(setup.locationBasePlanId)?.locationName ?? '',
      location: data.site(data.siteIdOfSetup(setup))?.name ?? '',
      scheme: setup.name,
      scenes: use.scenes.isEmpty ? '' : 'Esc ${use.scenes.join(', ')}',
      shootDay: use.days.join(' · '),
      date: DateTime.now(),
    ),
  );
}
