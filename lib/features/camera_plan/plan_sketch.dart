import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../shared/shot_images/shot_image_menu.dart';
import 'camera_plan_editor.dart';
import 'floor_plan_repository.dart';
import 'plan_data.dart';
import 'plan_thumbnail.dart';

/// Un boceto de planta es un esquema de luz en estado «boceto»: se dibuja
/// en el editor de siempre, a mano alzada o con sus elementos, y más
/// adelante se marca «en desarrollo» o «definitivo» sin rehacerlo.

/// Pregunta cómo se va a dibujar y crea el boceto en el set (o en la
/// localización). Devuelve el boceto y si se dibuja a mano; nulo si se
/// cancela.
Future<({LightSetup setup, bool freehand})?> createPlanSketch(
  BuildContext context,
  AppDatabase db, {
  required int projectId,
  required int? setId,
  required int? siteId,
  required String label,
}) async {
  final palette = context.palette;
  final freehand = await showDialog<bool>(
    context: context,
    builder: (context) => SimpleDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text('Boceto nuevo', style: AppTypography.titleMedium(palette)),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, true),
          child: const ListTile(
            leading: Icon(Icons.draw_outlined),
            title: Text('A mano alzada'),
            subtitle: Text('Con el ratón o el Apple Pencil, sobre el plano'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, false),
          child: const ListTile(
            leading: Icon(Icons.wb_incandescent_outlined),
            title: Text('Con elementos de la planta'),
            subtitle: Text('Focos, banderas, cámaras y actores'),
          ),
        ),
      ],
    ),
  );
  if (freehand == null) return null;

  final taken = {
    for (final s in await db.getLightSetupsForProject(projectId)) s.name,
  };
  var name = 'Boceto · $label';
  for (var i = 2; taken.contains(name); i++) {
    name = 'Boceto · $label ($i)';
  }
  final setup = await FloorPlanRepository(db).createLightSetup(
    projectId: projectId,
    setId: setId,
    siteId: setId == null ? siteId : null,
    name: name,
    status: 'boceto',
  );
  await db.touchProjectContent(projectId);
  return (setup: setup, freehand: freehand);
}

/// Miniatura de un boceto dibujado, con su rótulo.
class PlanSketchThumbnail extends StatelessWidget {
  final PlanProjectData data;
  final LightSetup setup;

  const PlanSketchThumbnail({
    super.key,
    required this.data,
    required this.setup,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PlanThumbnail(
          elements: data.ownOfSetup(setup),
          inherited: data.inheritedOfSetup(setup),
          drawings: data.drawingsOfSetup(setup),
          inheritedOpacity: 0.3,
          focus: data.zoneOf(data.set(setup.locationBasePlanId)),
          emptyIcon: Icons.draw_outlined,
        ),
        const Positioned(left: 3, bottom: 3, child: PlanSketchBadge()),
      ],
    );
  }
}

/// Rótulo «BOCETO».
class PlanSketchBadge extends StatelessWidget {
  const PlanSketchBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'BOCETO',
        style: TextStyle(
          fontSize: 8,
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Abre un boceto en el editor de planta.
Future<void> openPlanSketch(
  BuildContext context,
  LightSetup setup, {
  bool freehand = false,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CameraPlanEditor.lightSetup(
        projectId: setup.projectId,
        lightSetupId: setup.id,
        setupName: setup.name,
        startDrawing: freehand,
      ),
    ),
  );
}

/// Lo que el menú de bocetos de un plano necesita de las plantas: pintar
/// los bocetos dibujados que el plano enseña y ofrecer los que hay.
const planSketchDelegate = ShotSketchDelegate(
  thumbnail: _delegateThumbnail,
  section: _delegateSection,
  open: _delegateOpen,
);

Widget _delegateThumbnail(BuildContext context, Shot shot, int setupId) {
  return PlanDataBuilder(
    projectId: shot.projectId,
    builder: (context, data) {
      final setup = data.setup(setupId);
      if (setup == null) {
        return const Center(child: Icon(Icons.broken_image_outlined, size: 16));
      }
      return PlanSketchThumbnail(data: data, setup: setup);
    },
  );
}

Widget _delegateSection(BuildContext context, Shot shot) =>
    _SketchSection(shot: shot);

Future<void> _delegateOpen(BuildContext context, Shot shot, int setupId) async {
  final db = ProviderScope.containerOf(context).read(databaseProvider);
  final setup = await db.getLightSetupById(setupId);
  if (setup == null || !context.mounted) return;
  await openPlanSketch(context, setup);
}

/// «Bocetos de la planta»: los que hay en la localización de la escena,
/// para enseñarlos en este plano, y la entrada para dibujar uno nuevo.
class _SketchSection extends ConsumerWidget {
  final Shot shot;

  const _SketchSection({required this.shot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.read(databaseProvider);
    return PlanDataBuilder(
      projectId: shot.projectId,
      builder: (context, data) {
        final current = data.shots.where((s) => s.id == shot.id).firstOrNull;
        final scene = data.scene(shot.sceneId);
        if (current == null || scene == null) return const SizedBox.shrink();
        final chosen = {
          for (final entry in planSketchEntriesOf(current))
            ?planSketchSetupId(entry),
        };
        final available = [
          for (final setup in data.sketchesForScene(scene))
            if (!chosen.contains(setup.id)) setup,
        ];
        final setId = data.setIdOfShot(current);
        final siteId = data.siteIdOfScene(scene);

        Future<void> draw() async {
          final created = await createPlanSketch(
            context,
            db,
            projectId: shot.projectId,
            setId: setId,
            siteId: siteId,
            label: 'Esc ${scene.number} P${current.number}',
          );
          if (created == null) return;
          await addShotPlanSketchSetup(
            db: db,
            shot: current,
            setupId: created.setup.id,
          );
          if (!context.mounted) return;
          await openPlanSketch(
            context,
            created.setup,
            freehand: created.freehand,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bocetos de la planta',
                    style: AppTypography.label(palette),
                  ),
                ),
                TextButton.icon(
                  onPressed: draw,
                  icon: const Icon(Icons.draw_outlined, size: 16),
                  label: const Text('Dibujar un boceto nuevo'),
                ),
              ],
            ),
            if (available.isEmpty)
              Text(
                chosen.isEmpty
                    ? 'Aún no hay bocetos dibujados en esta localización. '
                          'Se dibujan aquí o en Plantas de cámara y luz.'
                    : 'Este plano ya enseña todos los bocetos de su '
                          'localización.',
                style: AppTypography.caption(palette),
              )
            else
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: available.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final setup = available[i];
                    return Tooltip(
                      message: 'Enseñar este boceto en el plano',
                      child: InkWell(
                        onTap: () => addShotPlanSketchSetup(
                          db: db,
                          shot: current,
                          setupId: setup.id,
                        ),
                        child: SizedBox(
                          width: 124,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  height: 70,
                                  width: 124,
                                  child: PlanSketchThumbnail(
                                    data: data,
                                    setup: setup,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                setup.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption(palette),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
