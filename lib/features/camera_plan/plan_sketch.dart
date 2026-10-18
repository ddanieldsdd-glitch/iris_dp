import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/media_storage.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../shared/annotations/annotation_document.dart';
import '../../shared/annotations/sketch_pad.dart';
import '../../shared/shot_images/shot_image_menu.dart';
import 'camera_plan_editor.dart';
import 'floor_plan_repository.dart';
import 'light_setup_actions.dart';
import 'plan_item_actions.dart';
import 'plan_data.dart';
import 'plan_thumbnail.dart';

/// Un boceto es una planta para empezar a pensar la luz de una escena, sin
/// planos del guion técnico: con los elementos de la planta (focos,
/// banderas, cámaras y actores sobre el entorno) o a mano alzada, en su
/// propio lienzo cuadriculado. Nunca se dibuja encima de una planta.

/// Pregunta qué boceto se quiere (o usa [kind]) y lo crea en la escena,
/// junto a su set o su localización para ver el entorno. Nulo si se
/// cancela.
Future<LightSetup?> createPlanSketch(
  BuildContext context,
  AppDatabase db, {
  required int projectId,
  required int? sceneId,
  required int? setId,
  required int? siteId,
  required String label,
  String? kind,
}) async {
  final palette = context.palette;
  final chosen =
      kind ??
      await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          backgroundColor: palette.surfaceElevated,
          title: Text(
            'Boceto nuevo',
            style: AppTypography.titleMedium(palette),
          ),
          children: [
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, LightSetupKind.sketchFreehand),
              child: const ListTile(
                leading: Icon(Icons.draw_outlined),
                title: Text('A mano alzada'),
                subtitle: Text(
                  'En su propio lienzo cuadriculado, con ratón o Apple '
                  'Pencil',
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, LightSetupKind.sketchElements),
              child: const ListTile(
                leading: Icon(Icons.wb_incandescent_outlined),
                title: Text('Con elementos de la planta'),
                subtitle: Text(
                  'Focos, banderas, cámaras y actores sobre el entorno',
                ),
              ),
            ),
          ],
        ),
      );
  if (chosen == null) return null;

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
    kind: chosen,
    sceneId: sceneId,
  );
  return setup;
}

/// Abre el lienzo cuadriculado del boceto a mano y guarda lo dibujado:
/// la imagen y sus trazos, para seguir otro día.
Future<void> drawFreehandSketch(
  BuildContext context,
  AppDatabase db,
  LightSetup setup,
) async {
  final current = setup.sketchImagePath;
  final result = await showSketchPad(
    context,
    title: setup.name,
    initial: current == null
        ? const AnnotationDocument()
        : readSketchDocument(current),
    aspectRatio: 4 / 3,
    gridPaper: true,
  );
  if (result == null) return;
  // Cada boceto tiene su archivo (una copia duplicada no pisa el original).
  final fileName = 'boceto_${setup.uid ?? setup.id}.png';
  final path = await MediaStorage.writeProjectFileBytes(
    projectId: setup.projectId,
    subfolder: 'light_sketches',
    bytes: result.png,
    fileName: fileName,
  );
  await writeSketchDocument(path, result.document);
  await FileImage(File(path)).evict();
  final fresh = await db.getLightSetupById(setup.id) ?? setup;
  await db.updateLightSetup(fresh.copyWith(sketchImagePath: Value(path)));
}

/// Pasa un dibujo hecho encima de una planta (de antes) a un boceto a mano
/// nuevo, con su imagen y sus trazos. Con [shot], el plano lo sigue
/// enseñando. Devuelve el boceto.
Future<LightSetup> moveDrawingToFreehandSketch(
  AppDatabase db, {
  required int projectId,
  required AnnotationDocument document,
  required String name,
  required int? sceneId,
  required int? setId,
  required int? siteId,
  Shot? shot,
  Size size = const Size(1600, 1200),
}) async {
  final setup = await FloorPlanRepository(db).createLightSetup(
    projectId: projectId,
    setId: setId,
    siteId: setId == null ? siteId : null,
    name: name,
    kind: LightSetupKind.sketchFreehand,
    sceneId: sceneId,
  );
  final png = await renderSketchPng(document, size: size, gridPaper: true);
  final path = await MediaStorage.writeProjectFileBytes(
    projectId: projectId,
    subfolder: 'light_sketches',
    bytes: png,
    fileName: 'boceto_${setup.uid ?? setup.id}.png',
  );
  await writeSketchDocument(path, document);
  final withImage = setup.copyWith(sketchImagePath: Value(path));
  await db.updateLightSetup(withImage);
  if (shot != null) {
    await addShotPlanSketchSetup(db: db, shot: shot, setupId: setup.id);
  }
  return withImage;
}

/// Abre un boceto: el de elementos en el editor de planta, el de mano
/// alzada en su lienzo.
Future<void> openPlanSketch(BuildContext context, LightSetup setup) async {
  if (setup.kind == LightSetupKind.sketchFreehand) {
    final db = ProviderScope.containerOf(context).read(databaseProvider);
    return drawFreehandSketch(context, db, setup);
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CameraPlanEditor.lightSetup(
        projectId: setup.projectId,
        lightSetupId: setup.id,
        setupName: setup.name,
      ),
    ),
  );
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
    final image = setup.kind == LightSetupKind.sketchFreehand
        ? setup.sketchImagePath
        : null;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (setup.kind == LightSetupKind.sketchFreehand)
          image != null && File(image).existsSync()
              ? Image.file(File(image), fit: BoxFit.cover)
              : const ColoredBox(
                  color: Colors.white,
                  child: CustomPaint(
                    painter: SketchGridPainter(),
                    child: Center(
                      child: Icon(Icons.draw_outlined, color: Colors.black38),
                    ),
                  ),
                )
        else
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
            sceneId: scene.id,
            setId: setId,
            siteId: siteId,
            label: 'Esc ${scene.number} P${current.number}',
          );
          if (created == null) return;
          // El boceto es de la escena; este plano solo lo enseña.
          await addShotPlanSketchSetup(
            db: db,
            shot: current,
            setupId: created.id,
          );
          if (!context.mounted) return;
          await openPlanSketch(context, created);
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

/// Fila de bocetos (de una escena o libres): plantas para pensar la luz
/// antes de tener planos, con elementos o a mano. No se les arrastran
/// planos.
class PlanSketchStrip extends ConsumerWidget {
  final String title;
  final List<LightSetup> sketches;
  final PlanProjectData data;
  final ValueChanged<LightSetup> onOpen;
  final VoidCallback onNewElements;
  final VoidCallback onNewFreehand;
  /// Pasar un boceto con elementos a esquema de verdad; nulo donde no hay
  /// set al que llevarlo.
  final ValueChanged<LightSetup>? onToPlan;

  const PlanSketchStrip({
    super.key,
    required this.title,
    required this.sketches,
    required this.data,
    required this.onOpen,
    required this.onNewElements,
    required this.onNewFreehand,
    this.onToPlan,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.read(databaseProvider);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: AppTypography.label(palette)),
              const Spacer(),
              TextButton.icon(
                onPressed: onNewElements,
                icon: const Icon(Icons.wb_incandescent_outlined, size: 15),
                label: const Text('Boceto con elementos'),
              ),
              TextButton.icon(
                onPressed: onNewFreehand,
                icon: const Icon(Icons.draw_outlined, size: 15),
                label: const Text('Boceto a mano'),
              ),
            ],
          ),
          if (sketches.isEmpty)
            Text(
              'Para empezar a pensar la luz sin planos todavía: sobre el '
              'entorno con focos y cámaras, o a mano alzada.',
              style: AppTypography.caption(
                palette,
              ).copyWith(color: palette.textTertiary),
            )
          else
            SizedBox(
              height: 142,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: sketches.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
                itemBuilder: (context, i) {
                  final sketch = sketches[i];
                  final freehand =
                      sketch.kind == LightSetupKind.sketchFreehand;
                  return SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => onOpen(sketch),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              height: 90,
                              width: 150,
                              child: PlanSketchThumbnail(
                                data: data,
                                setup: sketch,
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              freehand
                                  ? Icons.draw_outlined
                                  : Icons.wb_incandescent_outlined,
                              size: 12,
                              color: palette.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                sketch.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption(palette),
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Opciones del boceto',
                              padding: EdgeInsets.zero,
                              iconSize: 16,
                              icon: Icon(
                                Icons.more_horiz,
                                size: 16,
                                color: palette.textSecondary,
                              ),
                              onSelected: (action) async {
                                switch (action) {
                                  case 'rename':
                                    final name = await askPlanName(
                                      context,
                                      title: 'Nombre del boceto',
                                      initial: sketch.name,
                                    );
                                    if (name != null) {
                                      await db.updateLightSetup(
                                        sketch.copyWith(name: name),
                                      );
                                    }
                                  case 'plan':
                                    onToPlan?.call(sketch);
                                  case 'delete':
                                    if (!context.mounted) return;
                                    await LightSetupActions(
                                      context,
                                      db,
                                      sketch,
                                      0,
                                    ).delete();
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'rename',
                                  child: Text('Renombrar'),
                                ),
                                if (!freehand && onToPlan != null)
                                  const PopupMenuItem(
                                    value: 'plan',
                                    child: Text('Convertir en esquema del set'),
                                  ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Borrar boceto',
                                    style: TextStyle(color: palette.error),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
