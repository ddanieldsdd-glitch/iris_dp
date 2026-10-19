import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/clipboard_image_reader.dart';
import '../../core/utils/export_file_saver.dart';
import '../../core/utils/media_storage.dart';
import '../../core/utils/shot_reference_import.dart';
import '../../shared/annotations/annotation_document.dart';
import '../../shared/annotations/sketch_pad.dart';
import '../../shared/shot_images/shot_image_menu.dart';
import 'camera_plan_editor.dart';
import 'camera_plan_grouping.dart';
import 'floor_plan_repository.dart';
import 'floor_plan_scope.dart';
import 'plan_image_widgets.dart';
import 'plan_images.dart';
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

/// Revisión de un boceto a mano: cambia cada vez que se guarda el dibujo.
String sketchRevision() =>
    jsonEncode({'rev': DateTime.now().toUtc().millisecondsSinceEpoch});

/// La imagen que se calca en un boceto a mano: una imagen de la planta del
/// boceto (viaja como las demás).
Future<PlanImage?> sketchTraceImage(AppDatabase db, LightSetup setup) async =>
    (await PlanImageStore(
      db,
    ).forLayers(projectId: setup.projectId, lightSetupId: setup.id)).lastOrNull;

/// Pone, cambia o quita la imagen para calcar de un boceto a mano: pegada
/// (Google Maps, Miro…), del moodboard o de un archivo.
Future<void> chooseSketchTraceImage(
  BuildContext context,
  AppDatabase db,
  LightSetup setup,
) async {
  final store = PlanImageStore(db);
  final previous = await sketchTraceImage(db, setup);
  if (!context.mounted) return;
  final picked = await _pickUnderlayBytes(
    context,
    db,
    setup.projectId,
    canRemove: previous != null,
  );
  if (picked == null) return;
  if (previous != null) await store.delete(previous);
  if (picked.remove) return;
  await store.add(
    projectId: setup.projectId,
    scope: FloorPlanScope.lightSetup,
    targetId: setup.id,
    bytes: picked.bytes!,
    extension: picked.extension,
    source: picked.source,
    center: const Offset(800, 600),
    longSide: 1600,
  );
}

/// Abre el boceto a mano en el folio (el del storyboard, en modo planta:
/// cuadrícula y sellos) y guarda lo dibujado:
/// la imagen y sus trazos, para seguir otro día.
Future<void> drawFreehandSketch(
  BuildContext context,
  AppDatabase db,
  LightSetup setup,
) async {
  final current = setup.sketchImagePath;
  // La imagen para calcar se ve debajo del papel, como el papel cebolla del
  // storyboard, y no sale en el dibujo.
  final trace = (await sketchTraceImage(db, setup))?.path;
  if (!context.mounted) return;
  final result = await showSketchPad(
    context,
    title: setup.name,
    initial: current == null
        ? const AnnotationDocument()
        : readSketchDocument(current),
    aspectRatio: 4 / 3,
    purpose: SketchSheetPurpose.lightingPlan,
    onionSkin: trace != null && File(trace).existsSync()
        ? FileImage(File(trace))
        : null,
    onionSkinLabel: 'Imagen para calcar',
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
  await db.updateLightSetup(
    fresh.copyWith(
      sketchImagePath: Value(path),
      // La ruta no cuenta en la sincronización (es de cada equipo): la
      // revisión dice a los demás que hay un dibujo nuevo que bajar.
      sketchJson: Value(sketchRevision()),
    ),
  );
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
  final png = await renderSketchPng(document, size: size);
  final path = await MediaStorage.writeProjectFileBytes(
    projectId: projectId,
    subfolder: 'light_sketches',
    bytes: png,
    fileName: 'boceto_${setup.uid ?? setup.id}.png',
  );
  await writeSketchDocument(path, document);
  final withImage = setup.copyWith(
    sketchImagePath: Value(path),
    sketchJson: Value(sketchRevision()),
  );
  await db.updateLightSetup(withImage);
  if (shot != null) {
    await addShotPlanSketchSetup(db: db, shot: shot, setupId: setup.id);
  }
  return withImage;
}

/// Qué imagen poner debajo del boceto a mano: pegada, del moodboard o de
/// un archivo; o quitar la que hay.
Future<
  ({Uint8List? bytes, String extension, String source, bool remove})?
>
_pickUnderlayBytes(
  BuildContext context,
  AppDatabase db,
  int projectId, {
  required bool canRemove,
}) async {
  final palette = context.palette;
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(
        'Imagen debajo del papel',
        style: AppTypography.titleMedium(palette),
      ),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'paste'),
          child: const ListTile(
            leading: Icon(Icons.content_paste),
            title: Text('Pegar (Google Maps, Miro, navegador…)'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'moodboard'),
          child: const ListTile(
            leading: Icon(Icons.photo_library_outlined),
            title: Text('Del moodboard'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, 'file'),
          child: const ListTile(
            leading: Icon(Icons.folder_open_outlined),
            title: Text('Archivo…'),
          ),
        ),
        if (canRemove)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'remove'),
            child: const ListTile(
              leading: Icon(Icons.hide_image_outlined),
              title: Text('Quitar la imagen'),
            ),
          ),
      ],
    ),
  );
  Future<({Uint8List? bytes, String extension, String source, bool remove})?>
  fromPath(String? path, String source) async {
    if (path == null || !File(path).existsSync()) return null;
    final ext = path.contains('.')
        ? path.substring(path.lastIndexOf('.'))
        : '.jpg';
    return (
      bytes: await File(path).readAsBytes(),
      extension: ext,
      source: source,
      remove: false,
    );
  }

  switch (choice) {
    case 'remove':
      return (bytes: null, extension: '', source: '', remove: true);
    case 'paste':
      final result = await ClipboardImageReader.read();
      final payload = result.payload;
      if (payload == null) return null;
      return (
        bytes: payload.bytes,
        extension: payload.extension,
        source: PlanImageSource.pasted,
        remove: false,
      );
    case 'moodboard':
      if (!context.mounted) return null;
      final picked = await pickMoodboardImage(context, db, projectId);
      return fromPath(picked?.imagePath, PlanImageSource.moodboard);
    case 'file':
      final file = await UserFilePicker.pickImage();
      return fromPath(file?.path, PlanImageSource.file);
  }
  return null;
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
    // Boceto a mano, o que llegó como imagen (la planta de un guion
    // importado): se enseña su imagen.
    final image = setup.sketchImagePath;
    if (image != null && File(image).existsSync()) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(image), fit: BoxFit.contain),
          const Positioned(left: 3, bottom: 3, child: PlanSketchBadge()),
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (setup.kind == LightSetupKind.sketchFreehand)
          const ColoredBox(
            color: Colors.white,
            child: Center(
              child: Icon(Icons.draw_outlined, color: Colors.black38),
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
            label: 'Esc ${scene.label} P${current.number}',
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
              height: 160,
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
                                  case 'trace':
                                    if (!context.mounted) return;
                                    await chooseSketchTraceImage(
                                      context,
                                      db,
                                      sketch,
                                    );
                                  case 'shots':
                                    if (!context.mounted) return;
                                    await showSketchShotsDialog(
                                      context,
                                      db,
                                      data,
                                      sketch,
                                    );
                                  case 'scene':
                                    if (!context.mounted) return;
                                    await moveSketchToScene(
                                      context,
                                      db,
                                      data,
                                      sketch,
                                    );
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
                                const PopupMenuItem(
                                  value: 'shots',
                                  child: Text('Asociar a planos…'),
                                ),
                                if (freehand)
                                  const PopupMenuItem(
                                    value: 'trace',
                                    child: Text('Imagen para calcar…'),
                                  ),
                                PopupMenuItem(
                                  value: 'scene',
                                  child: Text(
                                    sketch.sceneId == null
                                        ? 'Llevar a una escena…'
                                        : 'Cambiar de escena o hacer general…',
                                  ),
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
                        if (sketchShotLabels(data, sketch) case final shots
                            when shots.isNotEmpty)
                          Text(
                            'En ${shots.join(', ')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption(
                              palette,
                            ).copyWith(color: palette.textTertiary),
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

/// Planos que enseñan el boceto: «5·1», «5·2»…
List<String> sketchShotLabels(PlanProjectData data, LightSetup sketch) {
  final entry = 'setup:${sketch.id}';
  return [
    for (final shot in data.shots)
      if (planSketchEntriesOf(shot).contains(entry))
        '${data.scene(shot.sceneId)?.number ?? '?'}·${shot.number}',
  ];
}

/// Elige los planos que enseñan el boceto (como referencia: no cambia su
/// esquema de luz). Un boceto de escena ofrece los planos de su escena; uno
/// general, los de todas.
Future<void> showSketchShotsDialog(
  BuildContext context,
  AppDatabase db,
  PlanProjectData data,
  LightSetup sketch,
) async {
  final entry = 'setup:${sketch.id}';
  final scenes = [
    for (final scene in scenesInScriptOrder(data.scenes))
      if (sketch.sceneId == null || scene.id == sketch.sceneId) scene,
  ];
  final shots = [
    for (final scene in scenes) ...data.shotsOfScene(scene.id),
  ];
  final before = {
    for (final shot in shots)
      if (planSketchEntriesOf(shot).contains(entry)) shot.id,
  };
  final picked = {...before};
  final palette = context.palette;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: palette.surfaceElevated,
        title: Text(
          'Planos que enseñan «${sketch.name}»',
          style: AppTypography.titleMedium(palette),
        ),
        content: SizedBox(
          width: 420,
          child: shots.isEmpty
              ? Text(
                  'No hay planos todavía.',
                  style: AppTypography.bodyMedium(palette),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    Text(
                      'El boceto se ve en el plano (guion técnico y tablero) '
                      'como referencia; no cambia su esquema de luz.',
                      style: AppTypography.caption(
                        palette,
                      ).copyWith(color: palette.textSecondary),
                    ),
                    for (final scene in scenes)
                      if (data.shotsOfScene(scene.id).isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Escena ${scene.number} · '
                            '${scene.locationCanonical}',
                            style: AppTypography.caption(palette),
                          ),
                        ),
                        for (final shot in data.shotsOfScene(scene.id))
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: picked.contains(shot.id),
                            onChanged: (v) => setState(() {
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
  if (ok != true) return;
  for (final shot in shots) {
    final want = picked.contains(shot.id);
    final had = before.contains(shot.id);
    if (want && !had) {
      await addShotPlanSketchSetup(db: db, shot: shot, setupId: sketch.id);
    } else if (!want && had) {
      await removeShotPlanSketch(db: db, shot: shot, path: entry);
    }
  }
}

/// Lleva el boceto a otra escena, o lo deja general (sin escena). Con
/// elementos, toma el entorno de su nueva escena.
Future<void> moveSketchToScene(
  BuildContext context,
  AppDatabase db,
  PlanProjectData data,
  LightSetup sketch,
) async {
  final palette = context.palette;
  // -1 = general.
  final choice = await showDialog<int>(
    context: context,
    builder: (ctx) => SimpleDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(
        '¿A qué escena va «${sketch.name}»?',
        style: AppTypography.titleMedium(palette),
      ),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, -1),
          child: ListTile(
            leading: const Icon(Icons.public),
            title: const Text('General (sin escena)'),
            selected: sketch.sceneId == null,
          ),
        ),
        for (final scene in scenesInScriptOrder(data.scenes))
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, scene.id),
            child: ListTile(
              dense: true,
              title: Text('Escena ${scene.number} · ${scene.locationCanonical}'),
              selected: scene.id == sketch.sceneId,
            ),
          ),
      ],
    ),
  );
  if (choice == null) return;
  if (choice == -1) {
    await db.updateLightSetup(sketch.copyWith(sceneId: const Value(null)));
    return;
  }
  final scene = data.scene(choice);
  if (scene == null) return;
  final setId = scene.locationId;
  await db.updateLightSetup(
    sketch.copyWith(
      sceneId: Value(scene.id),
      locationBasePlanId: Value(setId),
      locationSiteId: Value(setId == null ? data.siteIdOfScene(scene) : null),
    ),
  );
}
