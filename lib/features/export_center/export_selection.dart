import '../../core/database/app_database.dart';
import '../camera_plan/camera_plan_grouping.dart';
import '../shoot_documents/shoot_plan.dart';

/// Los tres documentos que salen del proyecto o del plan de rodaje.
enum ExportDocument { storyboard, shootingPlan, technicalScript }

/// Desde dónde se elige lo que se exporta.
enum ExportScope { all, days, scenes, shots }

/// Lo elegido en el centro de exportación.
///
/// Por jornada se eligen bloques, no planos: un plano repetido en dos días
/// se puede dejar en uno solo. Por escena y por planos sueltos se eligen
/// planos.
class ExportSelection {
  final ExportScope scope;
  final Set<int> blockIds;
  final Set<int> shotIds;

  const ExportSelection({
    this.scope = ExportScope.all,
    this.blockIds = const {},
    this.shotIds = const {},
  });

  ExportSelection copyWith({
    ExportScope? scope,
    Set<int>? blockIds,
    Set<int>? shotIds,
  }) => ExportSelection(
    scope: scope ?? this.scope,
    blockIds: blockIds ?? this.blockIds,
    shotIds: shotIds ?? this.shotIds,
  );
}

/// Un plano ya colocado en el documento.
class ExportShot {
  final Shot shot;

  /// Su bloque en la jornada, si sale de una.
  final ShootDocumentBlock? block;

  /// Puesto en el orden de rodaje del día completo, aunque se exporte una
  /// parte: el documento dice lo mismo que el plan.
  final int? order;

  /// Las otras jornadas en las que está este plano.
  final List<String> alsoIn;

  const ExportShot(this.shot, {this.block, this.order, this.alsoIn = const []});
}

/// Tramo seguido de una escena. Una escena rodada a trozos da varios.
class ExportSceneSection {
  final Scene scene;
  final List<ExportShot> shots;

  const ExportSceneSection(this.scene, this.shots);

  List<Shot> get plainShots => [for (final s in shots) s.shot];
}

/// Una jornada con sus tramos, o el guion entero si [day] es nulo.
class ExportDaySection {
  final ShootDocument? day;
  final List<ExportSceneSection> scenes;

  const ExportDaySection(this.day, this.scenes);

  int get shotCount => scenes.fold(0, (n, s) => n + s.shots.length);
}

/// Todo lo que hace falta para resolver una selección.
/// Los [limit] primeros planos de [sections], para la vista previa.
({List<ExportDaySection> sections, int shown, int total}) previewSample(
  List<ExportDaySection> sections,
  int limit,
) {
  final total = sections.fold<int>(0, (n, s) => n + s.shotCount);
  if (total <= limit) return (sections: sections, shown: total, total: total);
  final kept = <ExportDaySection>[];
  var room = limit;
  for (final section in sections) {
    if (room == 0) break;
    final scenes = <ExportSceneSection>[];
    for (final tract in section.scenes) {
      if (room == 0) break;
      final shots = tract.shots.take(room).toList();
      room -= shots.length;
      scenes.add(ExportSceneSection(tract.scene, shots));
    }
    kept.add(ExportDaySection(section.day, scenes));
  }
  return (sections: kept, shown: limit, total: total);
}

class ExportSource {
  final Project project;
  final List<Scene> scenes;
  final List<Shot> shots;
  final ShootPlan plan;

  const ExportSource({
    required this.project,
    required this.scenes,
    required this.shots,
    required this.plan,
  });

  static Future<ExportSource?> load(AppDatabase db, int projectId) async {
    final project = await db.getProject(projectId);
    if (project == null) return null;
    final scenes = scenesInScriptOrder(
      await db.watchScenesForProject(projectId).first,
    );
    final shots = await db.getShotsForProject(projectId);
    final documents = await db.getShootDocumentsForProject(projectId);
    final blocks = await db.getShootDayBlocks(projectId);
    return ExportSource(
      project: project,
      scenes: scenes,
      shots: shots,
      plan: ShootPlan.from(
        documents: documents,
        blocks: blocks,
        scenes: scenes,
        shots: shots,
      ),
    );
  }

  /// Planos de [sceneId] en el orden del guion.
  List<Shot> shotsOfScene(int sceneId) =>
      shots.where((s) => s.sceneId == sceneId).toList()..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.number.compareTo(b.number);
      });
}

/// Pasa [selection] a jornadas, escenas y planos en orden de rodaje. Los tres
/// generadores reciben este mismo resultado.
///
/// «Todo» conserva las escenas sin planos, que el guion técnico sí enseña;
/// el resto de alcances solo devuelve lo elegido.
List<ExportDaySection> resolveExportSections(
  ExportSource source,
  ExportSelection selection,
) {
  switch (selection.scope) {
    case ExportScope.all:
      return [
        ExportDaySection(null, [
          for (final scene in source.scenes)
            ExportSceneSection(scene, [
              for (final shot in source.shotsOfScene(scene.id))
                ExportShot(shot),
            ]),
        ]),
      ];
    case ExportScope.scenes:
    case ExportScope.shots:
      final scenes = <ExportSceneSection>[];
      for (final scene in source.scenes) {
        final shots = [
          for (final shot in source.shotsOfScene(scene.id))
            if (selection.shotIds.contains(shot.id)) ExportShot(shot),
        ];
        if (shots.isNotEmpty) scenes.add(ExportSceneSection(scene, shots));
      }
      return scenes.isEmpty ? const [] : [ExportDaySection(null, scenes)];
    case ExportScope.days:
      final sceneById = {for (final s in source.scenes) s.id: s};
      final shotById = {for (final s in source.shots) s.id: s};
      final result = <ExportDaySection>[];
      for (final day in source.plan.days) {
        final tracts = <ExportSceneSection>[];
        var open = <ExportShot>[];
        Scene? current;
        void close() {
          if (current != null && open.isNotEmpty) {
            tracts.add(ExportSceneSection(current, open));
          }
          open = <ExportShot>[];
        }

        var order = 0;
        for (final block in source.plan.blocksByDay[day.id] ?? const []) {
          final shot = shotById[block.shotId];
          final scene = shot == null ? null : sceneById[shot.sceneId];
          if (shot == null || scene == null) continue;
          order++;
          if (!selection.blockIds.contains(block.id)) continue;
          if (current?.id != scene.id) {
            close();
            current = scene;
          }
          open.add(
            ExportShot(
              shot,
              block: block,
              order: order,
              alsoIn: _otherDays(source.plan, day.id, shot.id),
            ),
          );
        }
        close();
        if (tracts.isNotEmpty) result.add(ExportDaySection(day, tracts));
      }
      return result;
  }
}

List<String> _otherDays(ShootPlan plan, int dayId, int shotId) => [
  for (final day in plan.days)
    if (day.id != dayId &&
        (plan.blocksByDay[day.id] ?? const <ShootDocumentBlock>[]).any(
          (b) => b.shotId == shotId,
        ))
      day.name,
];
